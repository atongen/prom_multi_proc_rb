require "spec_helper"

RSpec.describe PromMultiProc::Proxy do
  let(:base) do
    base = PromMultiProc::Base.new(
      prefix: "app_",
      socket: File.expand_path("../../tmp/sockets/metrics.sock", __FILE__),
      metrics: File.expand_path("../../fixtures/files/metrics.json", __FILE__),
      logger: Logger.new(File::NULL),
      batch_size: 1,
      validate: true
    )
  end

  subject do
    PromMultiProc::Proxy.new(base)
  end

  it "should collect proxy methods" do
    subject.test_counter_total.inc(label1: "val1", label2: "val2")
    subject.test_counter_total.add(2, label1: "val1", label2: "val2")
    subject.test_counter_2_total.inc
    subject.test_counter_2_total.add(2)
    subject.test_gauge_total.set(2, label2: "val2", label3: "val3")
    subject.test_gauge_total.inc(label2: "val2", label3: "val3")
    subject.test_gauge_total.dec(label2: "val2", label3: "val3")
    subject.test_gauge_total.add(2, label2: "val2", label3: "val3")
    subject.test_gauge_total.sub(2, label2: "val2", label3: "val3")
    subject.test_gauge_total.set_to_current_time(label2: "val2", label3: "val3")
    subject.test_histogram_seconds.observe(0.3, label3: "val3", label4: "val4")
    subject.test_summary_seconds.observe(0.5, label4: "val4", label5: "val5")

    expect(subject.multis[0]).to eq([base.metric(:test_counter_total), "inc", 1.0, { label1: "val1", label2: "val2" }])
    expect(subject.multis[1]).to eq([base.metric(:test_counter_total), "add", 2, { label1: "val1", label2: "val2" }])
    expect(subject.multis[2]).to eq([base.metric(:test_counter_2_total), "inc", 1.0, {}])
    expect(subject.multis[3]).to eq([base.metric(:test_counter_2_total), "add", 2, {}])
    expect(subject.multis[4]).to eq([base.metric(:test_gauge_total), "set", 2, { label2: "val2", label3: "val3" }])
    expect(subject.multis[5]).to eq([base.metric(:test_gauge_total), "inc", 1.0, { label2: "val2", label3: "val3" }])
    expect(subject.multis[6]).to eq([base.metric(:test_gauge_total), "dec", 1.0, { label2: "val2", label3: "val3" }])
    expect(subject.multis[7]).to eq([base.metric(:test_gauge_total), "add", 2, { label2: "val2", label3: "val3" }])
    expect(subject.multis[8]).to eq([base.metric(:test_gauge_total), "sub", 2, { label2: "val2", label3: "val3" }])
    expect(subject.multis[9]).to eq([base.metric(:test_gauge_total), "set_to_current_time", 1.0, { label2: "val2", label3: "val3" }])
    expect(subject.multis[10]).to eq([base.metric(:test_histogram_seconds), "observe", 0.3, { label3: "val3", label4: "val4" }])
    expect(subject.multis[11]).to eq([base.metric(:test_summary_seconds), "observe", 0.5, { label4: "val4", label5: "val5" }])
  end

  it "should raise an exception with invalid labels" do
    subject.test_counter_total.inc(wrong: "value", label: "data")
    result = subject.multis[0]
    metric = result[0]
    args = result[1, 3]
    expect do
      metric.validate!(*args)
    end.to raise_exception(PromMultiProc::PromMultiProcError)
  end
end
