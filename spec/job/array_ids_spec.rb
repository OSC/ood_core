require "spec_helper"
require "ood_core/job/array_ids"

# Note that while all tests should pass not all passing inputs are valid for
# all Resource Managers

describe OodCore::Job::ArrayIds do
  context "when the spec is for a range" do
    it "returns the correct IDs" do
      expect( described_class.new('1-4').ids ).to eql([1, 2, 3, 4])
    end
  end

  context "when the spec is for a range with a step" do
    it "returns the correct IDs" do
      expect( described_class.new('1-4:2').ids ).to eql([1, 3])
    end
  end

  context "when the spec is for a compound range and single id" do
    it "returns the correct IDs" do
      expect( described_class.new('1-2,4').ids ).to eql([1, 2, 4])
    end
  end

  context "when the spec is for a list of single ids" do
    it "returns the correct IDs" do
      expect( described_class.new('1,3,5,7,11').ids ).to eql([1, 3, 5, 7, 11])
    end
  end

  context "when the spec is for multiple ranges" do
    it "returns the correct IDs" do
      expect( described_class.new('1-2,4-5,7-9').ids ).to eql([1, 2, 4, 5, 7, 8, 9])
    end
  end

  context "when the spec contains a percent modifier" do
    it "returns the correct IDs" do
      expect( described_class.new('1-4%2').ids ).to eql([1, 2, 3, 4])
    end
  end

  context "when the spec contains a mix" do
    it "returns the correct IDs" do
      expect( 
        described_class.new('1,3-6:3,7,9-11,13,15-17,20-30:2').ids
      ).to eql([1, 3, 6, 7, 9, 10, 11, 13, 15, 16, 17, 20, 22, 24, 26, 28, 30])
    end
  end

  context "when the spec contains a percent modifier, but no number" do
    it "returns an empty array" do
      expect( described_class.new('1-4%').ids ).to eql([])
    end
  end

  context "when the spec is nil" do
    it "returns an empty array" do
      expect(described_class.new(nil).ids).to eq([])
    end
  end

  context "when the spec is an empty string" do
    it "returns an empty array" do
      expect(described_class.new('').ids).to eq([])
    end
  end

  context "when the spec is not numeric" do
    it "returns an empty array" do
      expect(described_class.new('In the merry month of may...').ids).to eq([])
    end
  end

  context "when the spec is not valid and contains delimiters" do
    it "returns an empty array" do
      expect(described_class.new('2 - 1 = 1').ids).to eq([])
    end
  end

  context "when the spec is garbage" do
    it "returns an empty array" do
      expect(described_class.new('1!@-#$%^&*()DHKI%^&*(@)#@_!-=').ids).to eq([])
    end
  end
end
