require "spec_helper"

RSpec.describe PromMultiProc do
  it "has a version number" do
    expect(PromMultiProc::VERSION).not_to be nil
  end

  it "has types" do
    expect(PromMultiProc::TYPES).to have(4).items
  end
end
