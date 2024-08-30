require "ood_core/job/adapters/kubernetes/slug_generator"

RSpec.describe SlugGenerator do
  describe '#safe_slug' do
    subject { described_class.safe_slug(input) }

    {
      "preserves valid names" => ["jupyter-alex", "jupyter-alex"],
      "converts uppercase to lowercase" => ["jupyter-Alex", "jupyter-alex---3a1c285c"],
      "removes unicode characters" => ["jupyter-üni", "jupyter-ni---a5aaf5dd"]
    }.each do |description, (input, expected)|
      it description do
        expect(subject).to eq(expected)
      end
    end

    it "ensures slug doesn't end with '-'" do
      expect(described_class.safe_slug("jupyter-")).not_to end_with('-')
    end
  end
end