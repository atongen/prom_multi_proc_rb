require "spec_helper"
require "tmpdir"

# Threads do not survive fork, so a writer built in a pre-forking parent
# (unicorn with preload_app, puma in cluster mode, resque...) reaches every
# worker with a dead flush thread. These specs drive a real UNIX socket across
# a real fork rather than stubbing #write_socket, because the thing under test
# is precisely which process the flush thread is running in.
RSpec.describe PromMultiProc::Writer, "across a fork" do
  before { skip("fork unavailable on this platform") unless Process.respond_to?(:fork) }

  batch_timeout = 1
  # Deliberately far above the number of metrics written below: nothing here
  # may be delivered by filling a batch, only by the timer thread.
  batch_size = 100

  around do |example|
    Dir.mktmpdir("prom_multi_proc") do |dir|
      @dir = dir
      example.run
    end
  end

  let(:socket_path) do
    path = File.join(@dir, "metrics.sock")
    # UNIX socket paths are limited to ~104 bytes; fail loudly rather than
    # mysteriously never connecting.
    raise "socket path too long: #{path}" if path.bytesize > 100
    path
  end

  let!(:server) { UNIXServer.new(socket_path) }

  let(:writer) do
    PromMultiProc::Writer.new(
      socket: socket_path,
      batch_size: batch_size,
      batch_timeout: batch_timeout,
      validate: true
    )
  end

  let(:counter) { PromMultiProc::Counter.new("app_test_total", %i(label1), writer) }

  after do
    writer.shutdown
    server.close
  end

  # Runs the block in a forked child and waits for it. exit! skips at_exit, so
  # anything the parent received was sent by a flush thread running in the
  # child, not by an exit hook.
  def in_child
    pid = fork do
      status = 0
      begin
        yield
      rescue Exception => e # rubocop:disable Lint/RescueException
        warn("fork spec child: #{e.class}: #{e.message}")
        status = 1
      end
      exit!(status)
    end
    _, process_status = Process.wait2(pid)
    process_status
  end

  def read_batches(count:, timeout:)
    batches = []
    deadline = Time.now + timeout
    while batches.length < count
      remaining = deadline - Time.now
      break if remaining <= 0
      break unless IO.select([server], nil, nil, remaining)
      conn = server.accept
      batches << conn.read
      conn.close
    end
    batches
  end

  # The child writes two metrics, well under batch_size, and never shuts the
  # writer down. Only a flush thread running in the child can deliver them --
  # and the second one in particular can only have been sent by the timer,
  # since it is written after the restart has already happened.
  it "restarts the flush thread in the child" do
    counter # build the writer (and its thread) in the parent, before forking

    status = in_child do
      counter.inc(label1: "first")
      sleep(batch_timeout + 0.5)
      counter.inc(label1: "second")
      sleep(batch_timeout + 0.5)
    end

    expect(status.exitstatus).to eq(0)
    # Deliberately not asserting a batch count: if the tick slips past the
    # second write the two coalesce into one batch, which is still correct
    # behaviour. Either metric arriving at all already proves the restart --
    # batch_size is unreachable, shutdown is never called, and the child exit!s.
    batches = read_batches(count: 2, timeout: 5)
    expect(batches.join).to include("first").and include("second")
  end

  # Negative control for the spec above: same harness, same timings, but the
  # child pretends its inherited thread is still its own, which is exactly the
  # behaviour before the fix. It asserts the absence of a signal once the
  # mechanism is disabled, so if the spec above ever passes vacuously -- because
  # the harness reads batches that were never sent -- this one catches it.
  it "delivers nothing in the child when the restart is suppressed" do
    counter

    status = in_child do
      writer.instance_variable_set(:@thread_pid, Process.pid)
      counter.inc(label1: "first")
      sleep(batch_timeout + 0.5)
      counter.inc(label1: "second")
      sleep(batch_timeout + 0.5)
    end

    expect(status.exitstatus).to eq(0)
    expect(read_batches(count: 1, timeout: batch_timeout + 1)).to be_empty
  end

  # Integration cover for the buffer clear. Nothing here synchronizes the write
  # below with the fork, so the child may inherit an already drained buffer and
  # the example can pass without exercising the clear at all -- the deterministic
  # proof is "discards the buffer it inherited at fork time" further down.
  it "does not resend what the parent had already buffered" do
    counter
    counter.inc(label1: "parent_buffered") # buffered, batch_size is not reached

    status = in_child do
      counter.inc(label1: "child_only")
      sleep(batch_timeout + 0.5)
    end

    expect(status.exitstatus).to eq(0)
    # The parent's own timer flush and the child's, in either order.
    batches = read_batches(count: 2, timeout: 5)

    child_batch = batches.find { |b| b.include?("child_only") }
    expect(child_batch).not_to be_nil
    expect(child_batch).not_to include("parent_buffered")
    # The parent still owns that message and sends it exactly once.
    expect(batches.count { |b| b.include?("parent_buffered") }).to eq(1)
  end
end

RSpec.describe PromMultiProc::Writer, "flush thread lifecycle" do
  subject do
    PromMultiProc::Writer.new(
      socket: File.expand_path("../../tmp/sockets/metrics.sock", __FILE__),
      batch_size: 3,
      batch_timeout: 1,
      validate: true
    )
  end

  let(:counter) { PromMultiProc::Counter.new("app_test_total", %i(label1), subject) }

  after { subject.shutdown }

  it "does not restart the thread while the pid is unchanged" do
    allow(subject).to receive(:socket?).and_return(true)
    allow(subject).to receive(:write_socket).and_return(true)
    expect(subject).not_to receive(:start_flush_thread)

    5.times { counter.inc(label1: "val1") }
    subject.flush(force: true)
  end

  it "starts only one thread when several threads write after a fork" do
    allow(subject).to receive(:socket?).and_return(true)
    allow(subject).to receive(:write_socket).and_return(true)
    expect(subject).to receive(:start_flush_thread).once.and_call_original

    # A real fork leaves the inherited thread dead. Kill it here so it can't
    # win the restart race itself (which would make the count ambiguous) and
    # can't outlive the example, looping against torn down stubs.
    subject.instance_variable_get(:@thread).kill.join
    subject.instance_variable_set(:@thread_pid, -1) # simulate "some other process"

    10.times.map { Thread.new { counter.inc(label1: "val1") } }.each(&:join)
  end

  # Deterministic counterpart to the fork based "does not resend what the parent
  # had already buffered": no fork, no timers, so the clear is always exercised.
  it "discards the buffer it inherited at fork time" do
    allow(subject).to receive(:socket?).and_return(true)
    allow(subject).to receive(:write_socket).and_return(true)

    # Kill the inherited thread first, as fork would have. Left alive, its timer
    # flush can drain the buffer before the precondition below is checked.
    inherited_thread = subject.instance_variable_get(:@thread)
    inherited_thread.kill.join

    counter.inc(label1: "inherited") # one message, batch_size is 3, so it stays
    expect(subject.instance_variable_get(:@messages)).not_to be_empty

    subject.instance_variable_set(:@thread_pid, -1) # simulate "some other process"

    subject.send(:ensure_flush_thread)

    expect(subject.instance_variable_get(:@messages)).to be_empty
    expect(subject.instance_variable_get(:@thread)).not_to eq(inherited_thread)
  end

  it "does not restart the thread after shutdown" do
    subject.shutdown
    subject.instance_variable_set(:@thread_pid, -1) # simulate "some other process"
    expect(subject).not_to receive(:start_flush_thread)

    counter.inc(label1: "val1")
    subject.flush(force: true)
  end

  it "flushes what is still buffered on shutdown" do
    allow(subject).to receive(:socket?).and_return(true)
    expect(subject).to receive(:write_socket).once.and_return(true)

    counter.inc(label1: "val1") # one message, batch_size is 3
    subject.shutdown
  end
end
