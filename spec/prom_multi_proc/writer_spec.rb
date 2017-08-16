require "spec_helper"

RSpec.describe PromMultiProc::Writer do
  subject do
    PromMultiProc::Writer.new(
      socket: File.expand_path("../../tmp/sockets/metrics.sock", __FILE__),
      batch_size: 3,
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

  it "should not have a socket" do
    expect(subject.socket?).to be false
  end
end
