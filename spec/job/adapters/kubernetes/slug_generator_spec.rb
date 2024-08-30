require "ood_core/job/adapters/kubernetes/slug_generator"

RSpec.describe SlugGenerator do
  describe '#safe_slug' do
    subject { described_class.method(:safe_slug) }

    {
      "preserves valid names" => ["ood-alex", "ood-alex"],
      "converts uppercase to lowercase" => ["ood-Alex", "ood-alex---3a1c285c"],
      "removes unicode characters" => ["ood-üni", "ood-ni---a5aaf5dd"],
      "replaces @ with -" => ["user@email.com", "user-email-com---0925f997"],
      "deals with unicode and @ at the same time" => ["user-_@_emailß.com", "user-email-com---7e3a7efd"],
      ""
    }.each do |description, (input, expected)|
      it description do
        expect(subject.call(input)).to eq(expected)
      end
    end

    it "ensures slug doesn't end with '-'" do
      expect(described_class.safe_slug("ood-")).not_to end_with('-')
    end

    it "ensures slug doesn't start with '-'" do
      expect(described_class.safe_slug("-start")).not_to start_with('-')
    end
  end
end