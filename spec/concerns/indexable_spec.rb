require 'rails_helper'

# describe "Indexable", vcr: true do
#   subject  { create(:doi) }

#   it 'send_message' do
#     response = subject.send_message(subject.to_jsonapi)
#     expect(response.message_id).to be_present
#   end

#   it 'send_import_message' do
#     response = subject.send_import_message(subject.to_jsonapi)
#     expect(response.message_id).to be_present
#   end

#   it 'send_delete_message' do
#     response = subject.send_delete_message(subject.to_jsonapi)
#     expect(response.message_id).to be_present
#   end
# end

describe "Indexable class methods", elasticsearch: true do
  context "client" do
    let!(:client) { create(:client) }

    before do
      Client.import
      sleep 2
    end

    it 'find_by_id' do
      result = Client.find_by_id(client.symbol).results.first
      expect(result.symbol).to eq(client.symbol)
    end

    it 'find_by_id multiple' do
      results = Client.find_by_id(client.symbol).results
      expect(results.total).to eq(1)
    end

    it 'query' do
      results = Client.query(client.name).results
      expect(results.total).to eq(1)
    end
  end

  context "provider" do
    let!(:provider) { create(:provider) }

    before do
      Provider.import
      sleep 2
    end

    it 'find_by_id' do
      result = Provider.find_by_id(provider.symbol).results.first
      expect(result.symbol).to eq(provider.symbol)
    end

    it 'find_by_id multiple' do
      results = Provider.find_by_id(provider.symbol).results
      expect(results.total).to eq(1)
    end

    it 'query' do
      results = Provider.query(provider.name).results
      expect(results.total).to eq(1)
    end
  end

  context "doi" do
    let!(:doi) { create(:doi, titles: { title: "Soil investigations" }, publisher: "Pangaea", descriptions: { description: "this is a description" }, aasm_state: "findable") }
    let!(:dois) { create_list(:doi, 3, aasm_state: "findable") }

    before do
      Doi.import
      sleep 2
    end

    # it 'find_by_id' do
    #   result = Doi.find_by_id(doi.doi).results.first
    #   expect(result.doi).to eq(doi.doi)
    # end

    it 'query by doi' do
      results = Doi.query(doi.doi).results
      expect(results.total).to eq(1)
    end

    it 'query by title' do
      results = Doi.query("soil").results
      expect(results.total).to eq(1)
    end

    it 'query by publisher' do
      results = Doi.query("pangaea").results
      expect(results.total).to eq(1)
    end

    it 'query by description' do
      results = Doi.query("description").results
      expect(results.total).to eq(1)

      expect(results.response.aggregations.states).not_to be_nil
      expect(results.response.aggregations.prefixes).not_to be_nil
      expect(results.response.aggregations.created).not_to be_nil
      expect(results.response.aggregations.schema_versions).not_to be_nil
    end

    it 'query by description not found' do
      results = Doi.query("climate").results
      expect(results.total).to eq(0)
    end

    it 'query with cursor navigation' do
      results = Doi.query(nil, page: { size: 2, cursor: [] }).results
      expect(results.total).to eq(4)

      # Initial length should match the size
      expect(results.to_a.length).to eq(2)

      # Move onto next based on search_after
      # TODO fix cursor
      # results = Doi.query(nil, page: { size: 1, cursor: results.to_a.last[:sort] }).results
      # expect(results.to_a.length).to eq(1)
    end

    it 'query with scroll' do
      response = Doi.query(nil, page: { size: 2, scroll: "1m" })
      expect(response.total).to eq(4)

      # Initial length should match the size
      expect(response.results.to_a.length).to eq(2)

      # Move onto next based on scroll_id
      response = Doi.query(nil, page: { size: 1, scroll: "1m" }, scroll_id: response.scroll_id)
      expect(response.results.to_a.length).to eq(2)
    end

    context "doi_from_url" do
      subject { Doi }

      it "as id" do
        doi = "10.13039/501100009053"
        expect(subject.doi_from_url(doi)).to eq("10.13039/501100009053")
      end

      it "as url" do
        doi = "https://doi.org/10.13039/501100009053"
        expect(subject.doi_from_url(doi)).to eq("10.13039/501100009053")
      end

      it "as http url" do
        doi = "http://doi.org/10.13039/501100009053"
        expect(subject.doi_from_url(doi)).to eq("10.13039/501100009053")
      end
    end

    context "orcid_from_url" do
      subject { Doi }

      it "as id" do
        orcid = "orcid.org/0000-0003-3484-6875"
        expect(subject.orcid_from_url(orcid)).to eq("0000-0003-3484-6875")
      end

      it "as short id" do
        orcid = "0000-0003-3484-6875"
        expect(subject.orcid_from_url(orcid)).to eq("0000-0003-3484-6875")
      end

      it "as url" do
        orcid = "https://orcid.org/0000-0003-3484-6875"
        expect(subject.orcid_from_url(orcid)).to eq("0000-0003-3484-6875")
      end

      it "as http url" do
        orcid = "http://orcid.org/0000-0003-3484-6875"
        expect(subject.orcid_from_url(orcid)).to eq("0000-0003-3484-6875")
      end
    end

    context "ror_from_url" do
      subject { Doi }

      it "as id" do
        ror_id = "ror.org/046ak2485"
        expect(subject.ror_from_url(ror_id)).to eq("ror.org/046ak2485")
      end

      it "as short id" do
        ror_id = "046ak2485"
        expect(subject.ror_from_url(ror_id)).to eq("ror.org/046ak2485")
      end

      it "as url" do
        ror_id = "https://ror.org/046ak2485"
        expect(subject.ror_from_url(ror_id)).to eq("ror.org/046ak2485")
      end

      it "as http url" do
        ror_id = "http://ror.org/046ak2485"
        expect(subject.ror_from_url(ror_id)).to eq("ror.org/046ak2485")
      end

      it "nil" do
        ror_id = nil
        expect(subject.ror_from_url(ror_id)).to be_nil
      end
    end
  end
end
