require File.expand_path("../spec_helper", __FILE__)

describe "Instruction set_local" do
  before do
    @spec = InstructionSpec.new :set_local do |g|
      g.push_nil
      g.ret
    end
  end

  it "<describe instruction effect>" do
    @spec.run.should be_nil
  end
end
