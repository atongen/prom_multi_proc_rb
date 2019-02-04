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
    expect(subject).to receive(:write_socket).at_most(3).and_return(true)
    10.times do
      counter.inc(label1: "val1", label2: "val2")
    end
  end

  it "should not flush batch for multi metric" do
    expect(subject).to receive(:write_socket).at_most(1).and_return(true)
    multi = 10.times.map do
      [counter, "inc", 1.0, { label1: "val1", label2: "val2" }]
    end
    subject.write_multi(multi)
  end

  it "should flush after the batch timeout expires" do
    expect(subject).to receive(:write_socket).twice.and_return(true)
    counter.inc(label1: "val1", label2: "val2")
    sleep(1.2)
    counter.inc(label1: "val1", label2: "val2")
    sleep(1)
  end

  it "should not flush after the batch timeout expires when there are no messages" do
    expect(subject).to receive(:write_socket).never
    sleep(2)
  end

  it "should not have a socket" do
    expect(subject.socket?).to be false
  end
end
