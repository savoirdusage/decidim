# frozen_string_literal: true

require "spec_helper"

module Decidim
  module Proposals
    describe MarkdownToProposals do
      def should_parse_and_produce_proposals(num_proposals)
        proposals = Decidim::Proposals::Proposal.where(component: component)
        expect { parser.parse(document) }.to change { proposals.count }.by(num_proposals)
        proposals
      end

      def should_have_expected_states(proposal)
        expect(proposal.draft?).to be true
        expect(proposal.official?).to be true
      end

      let!(:component) { create(:proposal_component) }
      let(:parser) { MarkdownToProposals.new(component, create(:user)) }
      let(:items) { [] }
      let(:document) do
        items.join("\n")
      end

      describe "titles create sections and sub-sections" do
        context "with titles of level 1" do
          let(:title) { ::Faker::Book.title }

          before do
            items << "# #{title}\n"
          end

          it "create sections" do
            should_parse_and_produce_proposals(1)

            proposal = Proposal.last
            expect(proposal.title).to eq(title)
            expect(proposal.body).to eq(title)
            expect(proposal.position).to eq(1)
            expect(proposal.participatory_text_level).to eq(ParticipatoryTextSection::LEVELS[:section])
            should_have_expected_states(proposal)
          end
        end

        context "with titles of deeper levels" do
          let(:titles) { (0...5).collect { |idx| "#{idx}-#{::Faker::Book.title}" } }

          before do
            titles.each_with_index { |title, idx| items << "#{"#" * (2 + idx)} #{title}\n" }
          end

          it "create sub-sections" do
            expected_pos = 1

            proposals = should_parse_and_produce_proposals(5)

            proposals.order(:position).each_with_index do |proposal, idx|
              expect(proposal.title).to eq(titles[idx])
              expect(proposal.body).to eq(titles[idx])
              expect(proposal.position).to eq(expected_pos)
              expected_pos += 1
              expect(proposal.participatory_text_level).to eq("sub-section")
              should_have_expected_states(proposal)
            end
          end
        end
      end

      describe "paragraphs create articles" do
        let(:paragraph) { ::Faker::Lorem.paragraph }

        before do
          items << "#{paragraph}\n"
        end

        it "produces a proposal like an article" do
          should_parse_and_produce_proposals(1)

          proposal = Proposal.last
          # proposal titled with its numbering (position)
          expect(proposal.title).to eq("1")
          expect(proposal.body).to eq(paragraph)
          expect(proposal.position).to eq(1)
          expect(proposal.participatory_text_level).to eq(ParticipatoryTextSection::LEVELS[:article])
          should_have_expected_states(proposal)
        end
      end

      describe "links are parsed" do
        let(:text_w_link) { %[This text links to [Meta Decidim](https://meta.decidim.org "Community's meeting point").] }

        before do
          items << "#{text_w_link}\n"
        end

        it "contains the link as an html anchor" do
          should_parse_and_produce_proposals(1)

          proposal = Proposal.last
          # proposal titled with its numbering (position)
          # the paragraph and proposal's body
          expect(proposal.title).to eq("1")
          paragraph = %q(This text links to <a href="https://meta.decidim.org" title="Community's meeting point">Meta Decidim</a>.)
          expect(proposal.body).to eq(paragraph)
          expect(proposal.position).to eq(1)
          expect(proposal.participatory_text_level).to eq(ParticipatoryTextSection::LEVELS[:article])
          should_have_expected_states(proposal)
        end
      end

      describe "images are parsed" do
        let(:image) { %{Text with ![Important image for Decidim](https://meta.decidim.org/assets/decidim/decidim-logo-1f39092fb3e41d23936dc8aeadd054e2119807dccf3c395de88637e4187f0a3f.svg "Img title").} }

        before do
          items << "#{image}\n"
        end

        it "contains the image as an html img tag" do
          should_parse_and_produce_proposals(1)

          proposal = Proposal.last
          expect(proposal.title).to eq("1")
          paragraph = 'Text with <img src="https://meta.decidim.org/assets/decidim/decidim-logo-1f39092fb3e41d23936dc8aeadd054e2119807dccf3c395de88637e4187f0a3f.svg" alt="Important image for Decidim" title="Img title"/>.'
          expect(proposal.body).to eq(paragraph)
          expect(proposal.position).to eq(1)
          expect(proposal.participatory_text_level).to eq(ParticipatoryTextSection::LEVELS[:article])
          should_have_expected_states(proposal)
        end
      end
    end
  end
end
