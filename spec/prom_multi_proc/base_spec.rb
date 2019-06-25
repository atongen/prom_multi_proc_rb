require "spec_helper"
require "tempfile"

RSpec.describe PromMultiProc::Base do
  subject do
    PromMultiProc::Base.new(
      prefix: "app_",
      socket: File.expand_path("../../tmp/sockets/metrics.sock", __FILE__),
      metrics: File.expand_path("../../fixtures/files/metrics.json", __FILE__),
      logger: Logger.new(File::NULL),
      batch_size: 1,
      validate: true
    )
  end

  context "metrics" do
    context "#initialize" do
      let(:metrics_file) { Tempfile.new('metrics.json') }

      after(:each) do
        metrics_file.close
        metrics_file.unlink
      end

      def with_metrics(m)
        metrics_file << m
        metrics_file.flush
        PromMultiProc::Base.new(
          prefix: "app_",
          socket: File.expand_path("../../tmp/sockets/metrics.sock", __FILE__),
          metrics: metrics_file.path,
          logger: Logger.new(File::NULL),
          batch_size: 1,
          validate: true
        )
      end

      it "should raise an error if a metric is missing help" do
        metrics = <<-EOF
        [ { "type": "counter", "name": "app_something" } ]
        EOF
        expect {
          with_metrics(metrics)
        }.to raise_error(PromMultiProc::PromMultiProcError, /missing help/)
      end

      it "should raise an error if a metric's help is empty" do
        metrics = <<-EOF
        [ { "type": "counter", "name": "app_something", "help": "   " } ]
        EOF
        expect {
          with_metrics(metrics)
        }.to raise_error(PromMultiProc::PromMultiProcError, /missing help/)
      end
    end

    context "#metric?" do
      it "should indicate metric existance" do
        expect(subject.metric?(:test_counter_total)).to be true
        expect(subject.metric?(:test_gauge_total)).to be true
        expect(subject.metric?(:test_histogram_seconds)).to be true
        expect(subject.metric?(:test_summary_seconds)).to be true
        expect(subject.metric?(:some_other_thing)).to be false
      end
    end

    context "#metric" do
      it "should return the metric collector" do
        expect(subject.metric(:test_counter_total)).to be_a_kind_of(PromMultiProc::Counter)
        expect(subject.metric(:test_gauge_total)).to be_a_kind_of(PromMultiProc::Gauge)
        expect(subject.metric(:test_histogram_seconds)).to be_a_kind_of(PromMultiProc::Histogram)
        expect(subject.metric(:test_summary_seconds)).to be_a_kind_of(PromMultiProc::Summary)
        expect(subject.metric(:some_other_thing)).to be_nil
      end
    end

    context "#metrics" do
      it "should return an array of metric names" do
        expect(subject.metrics).to eq(%i(
          test_counter_total test_counter_2_total test_gauge_total
          test_histogram_seconds test_summary_seconds))
      end
    end

    context "#multi" do
      it "should collect multiple metrics" do
        metrics = [
          build_metric_object("test_counter_total", ["val1", "val2"], "inc", 1.0),
          build_metric_object("test_counter_total", ["val1", "val2"], "add", 2.0),
          build_metric_object("test_counter_2_total", [], "inc", 1.0),
          build_metric_object("test_counter_2_total", [], "add", 2.0),
          build_metric_object("test_gauge_total", ["val2", "val3"], "set", 2.0),
          build_metric_object("test_gauge_total", ["val2", "val3"], "inc", 1.0),
          build_metric_object("test_gauge_total", ["val2", "val3"], "dec", 1.0),
          build_metric_object("test_gauge_total", ["val2", "val3"], "add", 2.0),
          build_metric_object("test_gauge_total", ["val2", "val3"], "sub", 2.0),
          build_metric_object("test_gauge_total", ["val2", "val3"], "set_to_current_time", 1.0),
          build_metric_object("test_histogram_seconds", ["val3", "val4"], "observe", 0.3),
          build_metric_object("test_summary_seconds", ["val4", "val5"], "observe", 0.5)
        ]
        expect(subject.writer).to receive(:write_socket).once.with(metrics.to_json).and_return(true)
        subject.multi do |m|
          m.test_counter_total.inc(label1: "val1", label2: "val2")
          m.test_counter_total.add(2, label1: "val1", label2: "val2")
          m.test_counter_2_total.inc
          m.test_counter_2_total.add(2)
          m.test_gauge_total.set(2, label2: "val2", label3: "val3")
          m.test_gauge_total.inc(label2: "val2", label3: "val3")
          m.test_gauge_total.dec(label2: "val2", label3: "val3")
          m.test_gauge_total.add(2, label2: "val2", label3: "val3")
          m.test_gauge_total.sub(2, label2: "val2", label3: "val3")
          m.test_gauge_total.set_to_current_time(label2: "val2", label3: "val3")
          m.test_histogram_seconds.observe(0.3, label3: "val3", label4: "val4")
          m.test_summary_seconds.observe(0.5, label4: "val4", label5: "val5")
        end
      end
    end

    context "#test_counter_total" do
      it "should inc" do
        metric = build_metric("test_counter_total", ["val1", "val2"], "inc", 1.0)
        expect(subject.writer).to receive(:write_socket).once.with(metric).and_return(true)
        subject.test_counter_total.inc(label1: "val1", label2: "val2")
      end

      it "should add" do
        metric = build_metric("test_counter_total", ["val1", "val2"], "add", 2.0)
        expect(subject.writer).to receive(:write_socket).once.with(metric).and_return(true)
        subject.test_counter_total.add(2, label1: "val1", label2: "val2")
      end
    end

    context "#test_counter_2_total" do
      it "should inc" do
        metric = build_metric("test_counter_2_total", [], "inc", 1.0)
        expect(subject.writer).to receive(:write_socket).once.with(metric).and_return(true)
        subject.test_counter_2_total.inc
      end

      it "should add" do
        metric = build_metric("test_counter_2_total", [], "add", 2.0)
        expect(subject.writer).to receive(:write_socket).once.with(metric).and_return(true)
        subject.test_counter_2_total.add(2)
      end
    end

    context "#test_gauge_total" do
      it "should set" do
        metric = build_metric("test_gauge_total", ["val2", "val3"], "set", 2.0)
        expect(subject.writer).to receive(:write_socket).once.with(metric).and_return(true)
        subject.test_gauge_total.set(2, label2: "val2", label3: "val3")
      end

      it "should inc" do
        metric = build_metric("test_gauge_total", ["val2", "val3"], "inc", 1.0)
        expect(subject.writer).to receive(:write_socket).once.with(metric).and_return(true)
        subject.test_gauge_total.inc(label2: "val2", label3: "val3")
      end

      it "should dec" do
        metric = build_metric("test_gauge_total", ["val2", "val3"], "dec", 1.0)
        expect(subject.writer).to receive(:write_socket).once.with(metric).and_return(true)
        subject.test_gauge_total.dec(label2: "val2", label3: "val3")
      end

      it "should add" do
        metric = build_metric("test_gauge_total", ["val2", "val3"], "add", 2.0)
        expect(subject.writer).to receive(:write_socket).once.with(metric).and_return(true)
        subject.test_gauge_total.add(2, label2: "val2", label3: "val3")
      end

      it "should sub" do
        metric = build_metric("test_gauge_total", ["val2", "val3"], "sub", 2.0)
        expect(subject.writer).to receive(:write_socket).once.with(metric).and_return(true)
        subject.test_gauge_total.sub(2, label2: "val2", label3: "val3")
      end

      it "should set_to_current_time" do
        metric = build_metric("test_gauge_total", ["val2", "val3"], "set_to_current_time", 1.0)
        expect(subject.writer).to receive(:write_socket).once.with(metric).and_return(true)
        subject.test_gauge_total.set_to_current_time(label2: "val2", label3: "val3")
      end
    end

    context "#test_histogram_seconds" do
      it "should observe" do
        metric = build_metric("test_histogram_seconds", ["val3", "val4"], "observe", 0.3)
        expect(subject.writer).to receive(:write_socket).once.with(metric).and_return(true)
        subject.test_histogram_seconds.observe(0.3, label3: "val3", label4: "val4")
      end
    end

    context "#test_summary_seconds" do
      it "should observe" do
        metric = build_metric("test_summary_seconds", ["val4", "val5"], "observe", 0.5)
        expect(subject.writer).to receive(:write_socket).once.with(metric).and_return(true)
        subject.test_summary_seconds.observe(0.5, label4: "val4", label5: "val5")
      end
    end

    context "invalid labels" do
      it "should raise" do
        expect do
          subject.test_counter_total.inc(wrong: "value", label: "data")
        end.to raise_exception(PromMultiProc::PromMultiProcError)
      end
    end
  end

  def build_metric_object(name, label_values, method, value = 1.0)
    { name: "app_#{name}",
      method: method,
      value: value,
      label_values: label_values }
  end

  def build_metric(name, label_values, method, value = 1.0)
    [build_metric_object(name, label_values, method, value)].to_json
  end
end
