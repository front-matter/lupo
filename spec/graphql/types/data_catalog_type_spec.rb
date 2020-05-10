require "rails_helper"

describe DataCatalogType do
  describe "fields" do
    subject { described_class }

    it { is_expected.to have_field(:id).of_type(!types.ID) }
    it { is_expected.to have_field(:type).of_type("String!") }
    it { is_expected.to have_field(:name).of_type("String") }
    it { is_expected.to have_field(:alternateName).of_type("[String!]") }
    it { is_expected.to have_field(:description).of_type("String") }
    it { is_expected.to have_field(:certificates).of_type("[DefinedTerm!]") }
    it { is_expected.to have_field(:subjects).of_type("[DefinedTerm!]") }
    it { is_expected.to have_field(:citationCount).of_type("Int") }
    it { is_expected.to have_field(:viewCount).of_type("Int") }
    it { is_expected.to have_field(:downloadCount).of_type("Int") }
    it { is_expected.to have_field(:datasets).of_type("DatasetConnectionWithTotal") }
  end

  # describe "find data_catalog", elasticsearch: true, vcr: true do
  #   let(:client) { create(:client, re3data_id: "10.17616/r3xs37") }
  #   let(:doi) { create(:doi, client: client, aasm_state: "findable") }
  #   let(:source_doi) { create(:doi, client: client, aasm_state: "findable") }
  #   let(:source_doi2) { create(:doi, client: client, aasm_state: "findable") }
  #   let!(:citation_event) { create(:event_for_datacite_crossref, subj_id: "https://doi.org/#{doi.doi}", obj_id: "https://doi.org/#{source_doi.doi}", relation_type_id: "is-referenced-by", occurred_at: "2015-06-13T16:14:19Z") }
  #   let!(:citation_event2) { create(:event_for_datacite_crossref, subj_id: "https://doi.org/#{doi.doi}", obj_id: "https://doi.org/#{source_doi2.doi}", relation_type_id: "is-referenced-by", occurred_at: "2016-06-13T16:14:19Z") }

  #   before do
  #     Client.import
  #     Event.import
  #     Doi.import
  #     sleep 2
  #   end

  #   let(:query) do
  #     %(query {
  #       dataCatalog(id: "https://doi.org/10.17616/r3xs37") {
  #         id
  #         name
  #         alternateName
  #         description
  #         certificates {
  #           termCode
  #           name
  #         }
  #         softwareApplication {
  #           name
  #           url
  #           softwareVersion
  #         }
  #         citationCount
  #         viewCount
  #         downloadCount
  #         datasets {
  #           totalCount
  #           years {
  #             title
  #             count
  #           }
  #           nodes {
  #             id
  #             titles {
  #               title
  #             }
  #             citationCount
  #           }
  #         }
  #       }
  #     })
  #   end

  #   it "returns data_catalog information" do
  #     response = LupoSchema.execute(query).as_json

  #     expect(response.dig("data", "dataCatalog", "id")).to eq("https://doi.org/10.17616/r3xs37")
  #     expect(response.dig("data", "dataCatalog", "name")).to eq("PANGAEA")
  #     expect(response.dig("data", "dataCatalog", "alternateName")).to eq(["Data Publisher for Earth and Environmental Science"])
  #     expect(response.dig("data", "dataCatalog", "description")).to start_with("The information system PANGAEA is operated as an Open Access library")
  #     expect(response.dig("data", "dataCatalog", "certificates")).to eq([{"termCode"=>nil, "name"=>"CoreTrustSeal"}])
  #     expect(response.dig("data", "dataCatalog", "softwareApplication")).to eq([{"name"=>"other", "url"=>nil, "softwareVersion"=>nil}])
  #     expect(response.dig("data", "dataCatalog", "citationCount")).to eq(0)
  #     # TODO should be 1
  #     expect(response.dig("data", "dataCatalog", "datasets", "totalCount")).to eq(1)
  #     # expect(response.dig("data", "funder", "works", "years")).to eq([{"count"=>1, "title"=>"2011"}])
  #     # expect(response.dig("data", "funder", "works", "resourceTypes")).to eq([{"count"=>1, "title"=>"Dataset"}])
  #     # expect(response.dig("data", "funder", "works", "nodes").length).to eq(1)

  #     work = response.dig("data", "dataCatalog", "datasets", "nodes", 0)
  #     expect(work.dig("titles", 0, "title")).to eq("Data from: A new malaria agent in African hominids.")
  #     expect(work.dig("citationCount")).to eq(0)
  #   end
  # end

  describe "query data_catalogs", elasticsearch: true, vcr: true do
    let!(:dois) { create_list(:doi, 3) }
    let!(:doi) { create(:doi, aasm_state: "findable", creators:
      [{
        "familyName" => "Garza",
        "givenName" => "Kristian",
        "name" => "Garza, Kristian",
        "nameIdentifiers" => [{"nameIdentifier"=>"https://orcid.org/0000-0003-3484-6875", "nameIdentifierScheme"=>"ORCID", "schemeUri"=>"https://orcid.org"}],
        "nameType" => "Personal",
        "affiliation": [
          {
            "name": "University of Cambridge",
            "affiliationIdentifier": "https://ror.org/013meh722",
            "affiliationIdentifierScheme": "ROR"
          },
        ]
      }])
    }

    before do
      Doi.import
      sleep 2
    end

    let(:query) do
      %(query {
        dataCatalogs(query: "Dataverse") {
          totalCount
          nodes {
            id
            name
            alternateName
            description
            certificates {
              termCode
              name
            }
            softwareApplication {
              name
              url
              softwareVersion
            }
          }
        }
      })
    end

    it "returns data_catalog information" do
      response = LupoSchema.execute(query).as_json

      expect(response.dig("data", "dataCatalogs", "totalCount")).to eq(83)
      expect(response.dig("data", "dataCatalogs", "nodes").length).to eq(25)
      
      data_catalog = response.dig("data", "dataCatalogs", "nodes", 0)
      expect(data_catalog.fetch("id")).to eq("https://doi.org/10.17616/r37h04")
      expect(data_catalog.fetch("name")).to eq("AfricaRice Dataverse")
      expect(data_catalog.fetch("alternateName")).to eq(["Rice science at the service of Africa", "la science rizicole au service de l'Afrique"])
      expect(data_catalog.fetch("description")).to start_with("AfricaRice is a leading pan-African rice research organization")
      expect(data_catalog.fetch("certificates")).to be_empty
      expect(data_catalog.fetch("softwareApplication")).to eq([{"name"=>"DataVerse", "softwareVersion"=>nil, "url"=>nil}])
    end
  end
end
