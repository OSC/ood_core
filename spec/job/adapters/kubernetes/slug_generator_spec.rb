require "ood_core/job/adapters/kubernetes/slug_generator"

class TestSlugGenerator
    extend SlugGenerator
end

describe TestSlugGenerator do

    describe '#safe_slug' do

        it "preserves names that are already valid" do
            expect(SlugGenerator::safe_slug("jupyter-alex")).to eq("jupyter-alex")
        end

        it "converts upper case characters into lower case" do
            expect(SlugGenerator::safe_slug("jupyter-Alex")).to eq("jupyter-alex---3a1c285c")
        end

        it "removes unicode characters" do
            expect(SlugGenerator::safe_slug("jupyter-üni")).to eq("jupyter-ni---a5aaf5dd")
        end

        it "makes sure slug doesn't end with '-'" do

        end
    end
end
