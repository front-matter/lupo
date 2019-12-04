require 'rails_helper'

describe "Repository Prefixes", type: :request do
  let!(:client_prefixes)  { create_list(:client_prefix, 5) }
  let(:client_prefix) { create(:client_prefix) }
  let(:bearer) { User.generate_token(role_id: "staff_admin") }
  let(:headers) { {'HTTP_ACCEPT'=>'application/vnd.api+json', 'HTTP_AUTHORIZATION' => 'Bearer ' + bearer }}

  describe 'GET /repository-prefixes' do
    it 'returns repository-prefixes' do
      get '/repository-prefixes', nil, headers

      expect(last_response.status).to eq(200)
      expect(json['data'].size).to eq(5)
    end
  end

  describe 'GET /repository-prefixes/:uid' do
    context 'when the record exists' do
      it 'returns the repository-prefix' do
        get "/repository-prefixes/#{client_prefix.uid}", nil, headers
        
        expect(last_response.status).to eq(200)
        expect(json.dig("data", "id")).to eq(client_prefix.uid)
      end
    end

    context 'when the record does not exist' do
      it 'returns status code 404' do
        get "/repository-prefixes/xxx", nil, headers

        expect(last_response.status).to eq(404)
        expect(json["errors"].first).to eq("status"=>"404", "title"=>"The resource you are looking for doesn't exist.")
      end
    end
  end

  describe 'PATCH /repository-prefixes/:uid' do
    it 'returns method not supported error' do
      patch "/repository-prefixes/#{client_prefix.uid}", nil, headers

      expect(last_response.status).to eq(405)
      expect(json.dig("errors")).to eq([{"status"=>"405", "title"=>"Method not allowed"}])
    end
  end

  describe 'POST /repository-prefixes' do
    context 'when the request is valid' do
      let(:provider) { create(:provider) }
      let(:client) { create(:client, provider: provider) }
      let(:prefix) { create(:prefix) }
      let(:provider_prefix) { create(:provider_prefix, provider: provider, prefix: prefix) }
      let(:valid_attributes) do
        {
          "data" => {
            "type" => "repository-prefixes",
            "relationships": {
              "repository": {
                "data":{
                  "type": "repositories",
                  "id": client.symbol.downcase
                }
              },
              "provider-prefix": {
                "data":{
                  "type": "provider-prefixes",
                  "id": provider_prefix.prefix
                }
              },
              "prefix": {
                "data":{
                  "type": "prefixes",
                  "id": prefix.prefix
                }
              }
            }
          }
        }
      end

      it 'creates a repository-prefix' do
        post '/repository-prefixes', valid_attributes, headers

        expect(last_response.status).to eq(201)
        expect(json.dig('data', 'id')).not_to be_nil
      end
    end

    context 'when the request is invalid' do
      let!(:client)  { create(:client) }
      let(:not_valid_attributes) do
        {
          "data" => {
            "type" => "repository-prefixes"
          }
        }
      end

      it 'returns status code 422' do
        post '/repository-prefixes', not_valid_attributes, headers

        expect(last_response.status).to eq(422)
        expect(json["errors"].first).to eq("source"=>"client", "title"=>"Must exist")
      end
    end
  end
end