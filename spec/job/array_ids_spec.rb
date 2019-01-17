require "spec_helper"
require "ood_core/job/array_ids"

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
end
