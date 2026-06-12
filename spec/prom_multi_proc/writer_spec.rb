require "spec_helper"

RSpec.describe PromMultiProc::Writer do
  subject do
    PromMultiProc::Writer.new(
      socket: File.expand_path("../../tmp/sockets/metrics.sock", __FILE__),
      batch_size: 3,
      batch_timeout: 1,
      validate: true
    )
  end

  let(:counter) { PromMultiProc::Counter.new("app_test_total", %i(label1 label2), subject) }

  it "should flush batch at batch size" do
    allow(subject).to receive(:socket?).and_return(true)
    expect(subject).to receive(:write_socket).at_most(3).and_return(true)
    10.times do
      counter.inc(label1: "val1", label2: "val2")
    end
  end

  it "should not flush batch for multi metric" do
    allow(subject).to receive(:socket?).and_return(true)
    expect(subject).to receive(:write_socket).at_most(1).and_return(true)
    multi = 10.times.map do
      [counter, "inc", 1.0, { label1: "val1", label2: "val2" }]
    end
    subject.write_multi(multi)
  end

  it "should flush after the batch timeout expires" do
    allow(subject).to receive(:socket?).and_return(true)
    expect(subject).to receive(:write_socket).twice.and_return(true)
    counter.inc(label1: "val1", label2: "val2")
    sleep(1.2)
    counter.inc(label1: "val1", label2: "val2")
    sleep(1)
  end

  it "should not flush after the batch timeout expires when there are no messages" do
    allow(subject).to receive(:socket?).and_return(true)
    expect(subject).to receive(:write_socket).never
    sleep(2)
  end

  it "should not have a socket" do
    expect(subject.socket?).to be false
  end

  it "should be able to shut down the background thread" do
    expect(subject.instance_variable_get(:@thread)).to be_alive
    subject.shutdown
    sleep(0.05)
    expect(subject.instance_variable_get(:@thread)).not_to be_alive
  end

  it "should be idempotent to shut down twice" do
    subject.shutdown
    expect { subject.shutdown }.not_to raise_error
  end

  it "should warn only once when the socket does not exist" do
    expect(subject).to receive(:warn).once.with(/socket .* not available/)
    expect(subject).to receive(:write_socket).never
    3.times do
      counter.inc(label1: "val1", label2: "val2")
      subject.flush(force: true)
    end
  end

  it "should warn again if the socket disappears after a successful write" do
    subject.shutdown # stop the background flusher so the stub sequence below is deterministic
    allow(subject).to receive(:write_socket).and_return(true)
    allow(subject).to receive(:socket?).and_return(false, true, false)
    expect(subject).to receive(:warn).twice.with(/socket .* not available/)
    3.times do
      counter.inc(label1: "val1", label2: "val2")
      subject.flush(force: true)
    end
  end

  it "should warn on every unexpected error" do
    allow(subject).to receive(:socket?).and_return(true)
    allow(subject).to receive(:write_socket).and_raise(IOError)
    expect(subject).to receive(:warn).twice.with(/Failed to write batch/)
    2.times do
      counter.inc(label1: "val1", label2: "val2")
      subject.flush(force: true)
    end
  end

end
