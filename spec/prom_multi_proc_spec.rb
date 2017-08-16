require "spec_helper"

RSpec.describe PromMultiProc do
  it "has a version number" do
    expect(PromMultiProc::VERSION).not_to be nil
  end

  it "has types" do
    expect(PromMultiProc::TYPES).to have(4).items
  end

  it "has a metric regex" do
    expect(PromMultiProc::METRIC_RE).to match("this_is_a_valid_metric_name")
    expect(PromMultiProc::METRIC_RE).not_to match("this is not a valid metric name")
  end
end
