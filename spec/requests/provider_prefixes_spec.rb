require 'rails_helper'

describe "Provider Prefixes", type: :request   do
  let!(:provider_prefixes)  { create_list(:provider_prefix, 5) }
  let(:provider_prefix) { create(:provider_prefix) }
  let(:bearer) { User.generate_token(role_id: "staff_admin") }
  let(:headers) { {'ACCEPT'=>'application/vnd.api+json', 'CONTENT_TYPE'=>'application/vnd.api+json', 'Authorization' => 'Bearer ' + bearer }}

  describe 'GET /provider-prefixes' do
    before { get '/provider-prefixes', headers: headers }

    it 'returns provider-prefixes' do
      expect(json['data'].size).to eq(5)
    end

    it 'returns status code 200' do
      expect(response).to have_http_status(200)
    end
  end

  describe 'GET /provider-prefixes/:uid' do
    before { get "/provider-prefixes/#{provider_prefix.uid}", headers: headers }

    context 'when the record exists' do
      it 'returns the provider-prefix' do
        expect(json.dig("data", "id")).to eq(provider_prefix.uid)
      end

      it 'returns status code 200' do
        expect(response).to have_http_status(200)
      end
    end

    context 'when the record does not exist' do
      before { get "/provider-prefixes/xxx" , headers: headers}

      it 'returns status code 404' do
        expect(response).to have_http_status(404)
      end

      it 'returns a not found message' do
        expect(json["errors"].first).to eq("status"=>"404", "title"=>"The resource you are looking for doesn't exist.")
      end
    end
  end
end
