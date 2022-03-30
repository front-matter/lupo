
# frozen_string_literal: true

require "rails_helper"

describe ReferenceRepositoryType do
  describe "fields" do
    subject { described_class }

    it { is_expected.to have_field(:id).of_type(!types.ID) }
    it { is_expected.to have_field(:type).of_type("String!") }
    it { is_expected.to have_field(:clientId).of_type(types.ID) }
    it { is_expected.to have_field(:re3dataDoi).of_type(types.ID) }
    it { is_expected.to have_field(:name).of_type("String!") }
    it { is_expected.to have_field(:alternateName).of_type("[String!]") }
    it { is_expected.to have_field(:description).of_type("String") }
    it { is_expected.to have_field(:url).of_type("Url") }
    it { is_expected.to have_field(:re3dataUrl).of_type("Url") }
    it { is_expected.to have_field(:software).of_type("[String!]") }
    it { is_expected.to have_field(:repositoryType).of_type("[String!]") }
    it { is_expected.to have_field(:certificate).of_type("[String!]") }
    it { is_expected.to have_field(:language).of_type("[String!]") }
    it { is_expected.to have_field(:providerType).of_type("[String!]") }
    it { is_expected.to have_field(:pidSystem).of_type("[String!]") }
    it { is_expected.to have_field(:dataAccess).of_type("[TextRestriction!]") }
    it { is_expected.to have_field(:dataUpload).of_type("[TextRestriction!]") }
    it { is_expected.to have_field(:contact).of_type("[String!]") }
    it { is_expected.to have_field(:subject).of_type("[DefinedTerm!]") }

  end


  describe "find referenceRepository", elastic: true, vcr: true do
    let!(:client) { create(:client) }
    let!(:ref_repo) { create(:reference_repository, client_id: client.symbol,re3doi:  "10.17616/R3XS37") }

    let(:id_query) do
      "query($id: ID!){
        referenceRepository(id: $id) {
          id
          name
          alternateName
          re3dataDoi
        }
      }"
    end

    before do
      ReferenceRepository.import
      sleep 2
    end

    it "by client_id" do
      response = LupoSchema.execute(id_query, variables: { id: client.symbol }).as_json
      expect(response.dig("data", "referenceRepository", "name")).to eq(client.name)
      expect(response.dig("data", "referenceRepository", "name")).to eq(client.name)
    end

    it "by re3doi" do
      response = LupoSchema.execute(id_query, variables: { id: ref_repo.re3doi}).as_json
      expect(response.dig("data", "referenceRepository", "re3dataDoi")).to eq(ref_repo.re3doi)
      expect(response.dig("data", "referenceRepository", "name")).to eq(client.name)
    end

    it "by hashid" do
      response = LupoSchema.execute(id_query, variables: { id: ref_repo.hashid}).as_json
      expect(response.dig("data", "referenceRepository", "re3dataDoi")).to eq(ref_repo.re3doi)
      expect(response.dig("data", "referenceRepository", "name")).to eq(client.name)
    end
  end
end
