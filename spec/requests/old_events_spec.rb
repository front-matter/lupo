# frozen_string_literal: true

require "rails_helper"

describe EventsController, type: :request, elasticsearch: true, vcr: true do
  let(:provider) { create(:provider, symbol: "DATACITE") }
  let(:client) do
    create(
      :client,
      provider: provider,
      symbol: ENV["MDS_USERNAME"],
      password: ENV["MDS_PASSWORD"],
    )
  end

  before(:each) do
    allow(Time).to receive(:now).and_return(Time.mktime(2_015, 4, 8))
    allow(Time.zone).to receive(:now).and_return(Time.mktime(2_015, 4, 8))
  end

  let(:event) { build(:event) }
  let(:errors) { [{ "status" => "401", "title" => "Bad credentials." }] }

  # Successful response from creating via the API.
  let(:success) do
    {
      "id" => event.uuid,
      "type" => "events",
      "attributes" => {
        "subj-id" => "http://www.citeulike.org/user/dbogartoit",
        "obj-id" => "http://doi.org/10.1371/journal.pmed.0030186",
        "message-action" => "create",
        "source-token" => "citeulike_123",
        "relation-type-id" => "bookmarks",
        "source-id" => "citeulike",
        "total" => 1,
        "license" => "https://creativecommons.org/publicdomain/zero/1.0/",
        "occurred-at" => "2015-04-08T00:00:00.000Z",
        "subj" => {
          "@id" => "http://www.citeulike.org/user/dbogartoit",
          "@type" => "CreativeWork",
          "author" => [{ "givenName" => "dbogartoit" }],
          "name" => "CiteULike bookmarks for user dbogartoit",
          "publisher" => { "@type" => "Organization", "name" => "CiteULike" },
          "periodical" => {
            "@type" => "Periodical",
            "@id" => "https://doi.org/10.13039/100011326",
            "name" => "CiteULike",
            "issn" => "9812-847X",
          },
          "funder" => {
            "@type" => "Organization",
            "@id" => "https://doi.org/10.13039/100011326",
            "name" => "CiteULike",
          },
          "version" => "1.0",
          "proxy-identifiers" => %w[10.13039/100011326],
          "date-published" => "2006-06-13T16:14:19Z",
          "date-modified" => "2006-06-13T16:14:19Z",
          "url" => "http://www.citeulike.org/user/dbogartoit",
        },
        "obj" => {},
      },
    }
  end

  let(:token) { User.generate_token(role_id: "staff_admin") }
  let(:uuid) { SecureRandom.uuid }
  let(:headers) do
    {
      "HTTP_ACCEPT" => "application/vnd.api+json",
      "HTTP_AUTHORIZATION" => "Bearer #{token}",
    }
  end

  context "create" do
    let(:uri) { "/events" }
    let(:params) do
      {
        "data" => {
          "type" => "events",
          "id" => event.uuid,
          "attributes" => {
            "subj-id" => event.subj_id,
            "subj" => event.subj,
            "obj-id" => event.obj_id,
            "relation-type-id" => event.relation_type_id,
            "source-id" => event.source_id,
            "source-token" => event.source_token,
          },
        },
      }
    end

    context "as admin user" do
      it "JSON" do
        post uri, params, headers

        expect(last_response.status).to eq(201)
        expect(json["errors"]).to be_nil
        expect(json.dig("data", "id")).to eq(event.uuid)
        # expect(json.dig("data", "relationships", "dois", "data")).to eq([{"id"=>"10.1371/journal.pmed.0030186", "type"=>"dois"}])
      end
    end

    context "with very long url" do
      let(:url) do
        "http://navigator.eumetsat.int/soapservices/cswstartup?service=csw&version=2.0.2&request=getrecordbyid&outputschema=http%3A%2F%2Fwww.isotc211.org%2F2005%2Fgmd&id=eo%3Aeum%3Adat%3Amult%3Arac-m11-iasia"
      end
      let(:params) do
        {
          "data" => {
            "type" => "events",
            "attributes" => {
              "subj-id" => event.subj_id,
              "subj" => event.subj,
              "obj-id" => url,
              "relation-type-id" => event.relation_type_id,
              "source-id" => "datacite-url",
              "source-token" => event.source_token,
            },
          },
        }
      end

      it "JSON" do
        post uri, params, headers

        expect(last_response.status).to eq(201)
        expect(json["errors"]).to be_nil
        expect(json.dig("data", "id")).not_to eq(event.uuid)
        expect(json.dig("data", "attributes", "obj-id")).to eq(url)
      end
    end

    context "as staff user" do
      let(:token) { User.generate_token(role_id: "staff_user") }

      it "JSON" do
        post uri, params, headers

        expect(last_response.status).to eq(403)
        expect(json["errors"]).to eq(
          [
            {
              "status" => "403",
              "title" => "You are not authorized to access this resource.",
            },
          ],
        )
        expect(json["data"]).to be_nil
      end
    end

    context "as regular user" do
      let(:token) { User.generate_token(role_id: "user") }

      it "JSON" do
        post uri, params, headers

        expect(last_response.status).to eq(403)
        expect(json["errors"]).to eq(
          [
            {
              "status" => "403",
              "title" => "You are not authorized to access this resource.",
            },
          ],
        )
        expect(json["data"]).to be_blank
      end
    end

    context "without source-token" do
      let(:params) do
        {
          "data" => {
            "type" => "events",
            "attributes" => {
              "uuid" => uuid,
              "subj-id" => event.subj_id,
              "source-id" => event.source_id,
            },
          },
        }
      end

      it "JSON" do
        post uri, params, headers

        expect(last_response.status).to eq(422)
        expect(json["errors"]).to eq(
          [{ "status" => 422, "title" => "Source token can't be blank" }],
        )
        expect(json["data"]).to be_nil
      end
    end

    context "without source-id" do
      let(:params) do
        {
          "data" => {
            "type" => "events",
            "attributes" => {
              "uuid" => uuid,
              "subj-id" => event.subj_id,
              "source-token" => event.source_token,
            },
          },
        }
      end

      it "JSON" do
        post uri, params, headers

        expect(last_response.status).to eq(422)
        expect(json["errors"]).to eq(
          [{ "status" => 422, "title" => "Source can't be blank" }],
        )
        expect(json["data"]).to be_blank
      end
    end

    context "without subj-id" do
      let(:params) do
        {
          "data" => {
            "type" => "events",
            "attributes" => {
              "uuid" => uuid,
              "source-id" => event.source_id,
              "source-token" => event.source_token,
            },
          },
        }
      end

      it "JSON" do
        post uri, params, headers

        expect(last_response.status).to eq(422)
        expect(json["errors"]).to eq(
          [{ "status" => 422, "title" => "Subj can't be blank" }],
        )
        expect(json["data"]).to be_blank
      end
    end

    context "with wrong API token" do
      let(:headers) do
        {
          "HTTP_ACCEPT" => "application/vnd.api+json",
          "HTTP_AUTHORIZATION" => "Bearer 12345678",
        }
      end

      it "JSON" do
        post uri, params, headers
        expect(last_response.status).to eq(401)

        expect(json["errors"]).to eq(errors)
        expect(json["data"]).to be_blank
      end
    end

    context "with missing data param" do
      let(:params) do
        {
          "event" => {
            "type" => "events",
            "attributes" => { "uuid" => uuid, "source-token" => "123" },
          },
        }
      end

      it "JSON" do
        post uri, params, headers

        expect(last_response.status).to eq(422)
        expect(json.dig("errors", 0, "title")).to start_with("Invalid payload")
        expect(json["data"]).to be_blank
      end
    end

    context "with params in wrong format" do
      let(:params) do
        {
          "data" =>
            "10.1371/journal.pone.0036790 2012-05-15 New Dromaeosaurids (Dinosauria: Theropoda) from the Lower Cretaceous of Utah, and the Evolution of the Dromaeosaurid Tail",
        }
      end

      it "JSON" do
        post uri, params, headers

        expect(last_response.status).to eq(422)
        error = json["errors"].first
        expect(error["status"]).to eq("422")
        expect(error["title"]).to start_with("Invalid payload")
        expect(json["data"]).to be_blank
      end
    end

    context "existing entry" do
      let!(:event) { create(:event) }

      it "JSON" do
        post uri, params, headers
        expect(last_response.status).to eq(200)
        expect(json["errors"]).to be_nil
        expect(json.dig("data", "id")).to eq(event.uuid)
        # expect(json.dig("data", "relationships", "dois", "data")).to eq([{"id"=>"10.1371/journal.pmed.0030186", "type"=>"dois"}])
      end
    end

    context "with registrant information" do
      let(:uri) { "/events" }
      let(:params) do
        {
          "data" => {
            "type" => "events",
            "attributes" => {
              "subj-id" => "https://doi.org/10.18713/jimis-170117-1-2",
              "subj" => {
                "@id": "https://doi.org/10.18713/jimis-170117-1-2",
                "@type": "ScholarlyArticle",
                "datePublished": "2017",
                "proxyIdentifiers": [],
                "registrantId": "datacite.inist.umr7300",
              },
              "obj" => {
                "@id": "https://doi.org/10.1016/j.jastp.2013.05.001",
                "@type": "ScholarlyArticle",
                "datePublished": "2013-09",
                "proxyIdentifiers": %w[13646826],
                "registrantId": "datacite.crossref.citations",
              },
              "obj-id" => "https://doi.org/10.1016/j.jastp.2013.05.001",
              "relation-type-id" => "references",
              "source-id" => "datacite-crossref",
              "source-token" => "source-token",
            },
          },
        }
      end

      it "has registrant aggregation" do
        post uri, params, headers

        expect(last_response.status).to eq(201)
        expect(json["errors"]).to be_nil
        expect(json.dig("data", "id")).not_to eq(event.uuid)
        expect(json.dig("data", "attributes", "obj-id")).to eq(
          "https://doi.org/10.1016/j.jastp.2013.05.001",
        )

        Event.import
        sleep 2
        get uri, nil, headers

        expect(json.dig("meta", "registrants", 0, "count")).to eq(1)
        expect(json.dig("meta", "registrants", 0, "id")).to eq(
          "datacite.crossref.citations",
        )
      end
    end

    context "with nested attributes" do
      let(:uri) { "/events" }
      let(:params) do
        {
          "data" => {
            "type" => "events",
            "attributes" => {
              "subj-id" => "https://doi.org/10.18713/jimis-170117-1-2",
              "subj" => {
                "@id": "https://doi.org/10.18713/jimis-170117-1-2",
                "@type": "ScholarlyArticle",
                "datePublished": "2017",
                "proxyIdentifiers": [],
                "registrantId": "datacite.inist.umr7300",
              },
              "obj" => {
                "@id": "https://doi.org/10.1016/j.jastp.2013.05.001",
                "@type": "ScholarlyArticle",
                "datePublished": "2013-09",
                "proxyIdentifiers": %w[13646826],
                "registrantId": "datacite.crossref.citations",
              },
              "obj-id" => "https://doi.org/10.1016/j.jastp.2013.05.001",
              "relation-type-id" => "references",
              "source-id" => "datacite-crossref",
              "source-token" => "source-token",
            },
          },
        }
      end

      it "are correctly stored" do
        post uri, params, headers

        expect(last_response.status).to eq(201)
        event = Event.where(uuid: json.dig("data", "id")).first
        expect(event[:obj].has_key?("datePublished")).to be_truthy
        expect(event[:obj].has_key?("registrantId")).to be_truthy
        expect(event[:obj].has_key?("proxyIdentifiers")).to be_truthy
      end
    end
  end

  context "create crossref doi", vcr: true do
    let(:uri) { "/events" }
    let(:params) do
      {
        "data" => {
          "type" => "events",
          "attributes" => {
            "subj-id" => "https://doi.org/10.7554/elife.01567",
            "source-id" => "crossref-import",
            "relation-type-id" => nil,
            "source-token" => event.source_token,
          },
        },
      }
    end

    it "registered" do
      post uri, params, headers

      expect(last_response.status).to eq(201)
      expect(json["errors"]).to be_nil
      expect(json.dig("data", "id")).to be_present
      expect(json.dig("data", "attributes", "subj-id")).to eq(
        "https://doi.org/10.7554/elife.01567",
      )
    end
  end

  context "create crossref doi not found", vcr: true do
    let(:uri) { "/events" }
    let(:params) do
      {
        "data" => {
          "type" => "events",
          "attributes" => {
            "subj-id" => "https://doi.org/10.3389/fmicb.2019.01425",
            "source-id" => "crossref-import",
            "relation-type-id" => nil,
            "source-token" => event.source_token,
          },
        },
      }
    end

    it "not registered" do
      post uri, params, headers
      expect(last_response.status).to eq(201)
      expect(json["errors"]).to be_nil
      expect(json.dig("data", "id")).to be_present
      expect(json.dig("data", "attributes", "subj-id")).to eq(
        "https://doi.org/10.3389/fmicb.2019.01425",
      )
    end
  end

  context "create medra doi", vcr: true do
    let(:uri) { "/events" }
    let(:params) do
      {
        "data" => {
          "type" => "events",
          "attributes" => {
            "subj-id" => "https://doi.org/10.3280/ecag2018-001005",
            "source-id" => "medra-import",
            "relation-type-id" => nil,
            "source-token" => event.source_token,
          },
        },
      }
    end

    it "registered" do
      post uri, params, headers

      expect(last_response.status).to eq(201)
      expect(json["errors"]).to be_nil
      expect(json.dig("data", "id")).to be_present
      expect(json.dig("data", "attributes", "subj-id")).to eq(
        "https://doi.org/10.3280/ecag2018-001005",
      )
    end
  end

  context "create kisti doi", vcr: true do
    let(:uri) { "/events" }
    let(:params) do
      {
        "data" => {
          "type" => "events",
          "attributes" => {
            "subj-id" => "https://doi.org/10.5012/bkcs.2013.34.10.2889",
            "source-id" => "kisti-import",
            "relation-type-id" => nil,
            "source-token" => event.source_token,
          },
        },
      }
    end

    it "registered" do
      post uri, params, headers

      expect(last_response.status).to eq(201)
      expect(json["errors"]).to be_nil
      expect(json.dig("data", "id")).to be_present
      expect(json.dig("data", "attributes", "subj-id")).to eq(
        "https://doi.org/10.5012/bkcs.2013.34.10.2889",
      )
    end
  end

  context "create jalc doi", vcr: true do
    let(:uri) { "/events" }
    let(:params) do
      {
        "data" => {
          "type" => "events",
          "attributes" => {
            "subj-id" => "https://doi.org/10.1241/johokanri.39.979",
            "source-id" => "jalc-import",
            "relation-type-id" => nil,
            "source-token" => event.source_token,
          },
        },
      }
    end

    it "registered" do
      post uri, params, headers

      expect(last_response.status).to eq(201)
      expect(json["errors"]).to be_nil
      expect(json.dig("data", "id")).to be_present
      expect(json.dig("data", "attributes", "subj-id")).to eq(
        "https://doi.org/10.1241/johokanri.39.979",
      )
    end
  end

  context "create op doi", vcr: true do
    let(:uri) { "/events" }
    let(:params) do
      {
        "data" => {
          "type" => "events",
          "attributes" => {
            "subj-id" => "https://doi.org/10.2903/j.efsa.2018.5239",
            "source-id" => "op-import",
            "relation-type-id" => nil,
            "source-token" => event.source_token,
          },
        },
      }
    end

    it "registered" do
      post uri, params, headers

      expect(last_response.status).to eq(201)
      expect(json["errors"]).to be_nil
      expect(json.dig("data", "id")).to be_present
      expect(json.dig("data", "attributes", "subj-id")).to eq(
        "https://doi.org/10.2903/j.efsa.2018.5239",
      )
    end
  end

  context "upsert" do
    let(:uri) { "/events/#{event.uuid}" }
    let(:params) do
      {
        "data" => {
          "type" => "events",
          "id" => event.uuid,
          "attributes" => {
            "subj-id" => event.subj_id,
            "subj" => event.subj,
            "obj-id" => event.obj_id,
            "relation-type-id" => event.relation_type_id,
            "source-id" => event.source_id,
            "source-token" => event.source_token,
          },
        },
      }
    end

    context "as admin user" do
      it "JSON" do
        put uri, params, headers

        expect(last_response.status).to eq(201)
        expect(json["errors"]).to be_nil
        expect(json.dig("data", "id")).to eq(event.uuid)
        # expect(json.dig("data", "relationships", "dois", "data")).to eq([{"id"=>"10.1371/journal.pmed.0030186", "type"=>"dois"}])
      end
    end

    context "as staff user" do
      let(:token) { User.generate_token(role_id: "staff_user") }

      it "JSON" do
        put uri, params, headers

        expect(last_response.status).to eq(403)
        expect(json["errors"]).to eq(
          [
            {
              "status" => "403",
              "title" => "You are not authorized to access this resource.",
            },
          ],
        )
        expect(json["data"]).to be_nil
      end
    end

    context "as regular user" do
      let(:token) { User.generate_token(role_id: "user") }

      it "JSON" do
        put uri, params, headers

        expect(last_response.status).to eq(403)
        expect(json["errors"]).to eq(
          [
            {
              "status" => "403",
              "title" => "You are not authorized to access this resource.",
            },
          ],
        )
        expect(json["data"]).to be_blank
      end
    end

    context "without source-token" do
      let(:params) do
        {
          "data" => {
            "type" => "events",
            "id" => uuid,
            "attributes" => {
              "subj-id" => event.subj_id, "source-id" => event.source_id
            },
          },
        }
      end

      it "JSON" do
        put uri, params, headers

        expect(last_response.status).to eq(422)
        expect(json["errors"]).to eq(
          [{ "status" => 422, "title" => "Source token can't be blank" }],
        )
        expect(json["data"]).to be_nil
      end
    end

    context "without source-id" do
      let(:params) do
        {
          "data" => {
            "type" => "events",
            "id" => uuid,
            "attributes" => {
              "subj-id" => event.subj_id, "source-token" => event.source_token
            },
          },
        }
      end

      it "JSON" do
        put uri, params, headers

        expect(last_response.status).to eq(422)
        expect(json["errors"]).to eq(
          [{ "status" => 422, "title" => "Source can't be blank" }],
        )
        expect(json["data"]).to be_blank
      end
    end

    context "without subj-id" do
      let(:params) do
        {
          "data" => {
            "type" => "events",
            "id" => uuid,
            "attributes" => {
              "source-id" => event.source_id,
              "source-token" => event.source_token,
            },
          },
        }
      end

      it "JSON" do
        put uri, params, headers

        expect(last_response.status).to eq(422)
        expect(json["errors"]).to eq(
          [{ "status" => 422, "title" => "Subj can't be blank" }],
        )
        expect(json["data"]).to be_blank
      end
    end

    context "with wrong API token" do
      let(:headers) do
        {
          "HTTP_ACCEPT" => "application/vnd.api+json",
          "HTTP_AUTHORIZATION" => "Bearer 12345678",
        }
      end

      it "JSON" do
        put uri, params, headers

        expect(last_response.status).to eq(401)
        expect(json["errors"]).to eq(errors)
        expect(json["data"]).to be_blank
      end
    end

    context "with missing data param" do
      let(:params) do
        {
          "event" => {
            "type" => "events",
            "id" => uuid,
            "attributes" => { "source-token" => "123" },
          },
        }
      end

      it "JSON" do
        put uri, params, headers

        expect(last_response.status).to eq(422)
        expect(json.dig("errors", 0, "title")).to start_with("Invalid payload")
        expect(json["data"]).to be_blank
      end
    end

    context "with params in wrong format" do
      let(:params) do
        {
          "data" =>
            "10.1371/journal.pone.0036790 2012-05-15 New Dromaeosaurids (Dinosauria: Theropoda) from the Lower Cretaceous of Utah, and the Evolution of the Dromaeosaurid Tail",
        }
      end

      it "JSON" do
        put uri, params, headers

        expect(last_response.status).to eq(422)
        error = json["errors"].first
        expect(error["status"]).to eq("422")
        expect(error["title"]).to start_with("Invalid payload")
        expect(json["data"]).to be_blank
      end
    end

    context "entry already exists" do
      let!(:event) { create(:event) }

      it "JSON" do
        put uri, params, headers

        expect(last_response.status).to eq(200)
        expect(json["errors"]).to be_nil
        # expect(json.dig("data", "relationships", "dois", "data")).to eq([{"id"=>"10.1371/journal.pmed.0030186", "type"=>"dois"}])
      end
    end
  end

  context "update" do
    let(:event) { create(:event) }
    # let!(:doi) { create(:doi, doi: "10.1371/journal.pmed.0030186", aasm_state: "findable") }
    let(:uri) { "/events/#{event.uuid}?include=dois" }

    let(:params) do
      {
        "data" => {
          "type" => "events",
          "id" => event.uuid,
          "attributes" => {
            "subj-id" => event.subj_id,
            "subj" => event.subj,
            "obj-id" => event.obj_id,
            "relation-type-id" => event.relation_type_id,
            "source-id" => event.source_id,
            "source-token" => event.source_token,
          },
        },
      }
    end

    context "as admin user" do
      it "JSON" do
        put uri, params, headers

        expect(last_response.status).to eq(200)
        expect(json["errors"]).to be_nil
        # expect(json.dig("data", "relationships", "dois", "data")).to eq([{"id"=>"10.1371/journal.pmed.0030186", "type"=>"dois"}])
      end
    end

    context "as staff user" do
      let(:token) { User.generate_token(role_id: "staff_user") }

      it "JSON" do
        put uri, params, headers

        expect(last_response.status).to eq(403)
        expect(json["errors"]).to eq(
          [
            {
              "status" => "403",
              "title" => "You are not authorized to access this resource.",
            },
          ],
        )
        expect(json["data"]).to be_nil
      end
    end

    context "as regular user" do
      let(:token) { User.generate_token(role_id: "user") }

      it "JSON" do
        put uri, params, headers

        expect(last_response.status).to eq(403)
        expect(json["errors"]).to eq(
          [
            {
              "status" => "403",
              "title" => "You are not authorized to access this resource.",
            },
          ],
        )
        expect(json["data"]).to be_blank
      end
    end

    context "with wrong API token" do
      let(:headers) do
        {
          "HTTP_ACCEPT" => "application/vnd.api+json",
          "HTTP_AUTHORIZATION" => "Bearer 12345678",
        }
      end

      it "JSON" do
        put uri, params, headers

        expect(last_response.status).to eq(401)
        expect(json["errors"]).to eq(errors)
        expect(json["data"]).to be_blank
      end
    end

    context "with missing data param" do
      let(:params) do
        {
          "event" => {
            "type" => "events",
            "id" => uuid,
            "attributes" => { "source-token" => "123" },
          },
        }
      end

      it "JSON" do
        put uri, params, headers

        expect(last_response.status).to eq(422)
        expect(json.dig("errors", 0, "title")).to start_with("Invalid payload")
        expect(json["data"]).to be_blank
      end
    end

    context "with params in wrong format" do
      let(:params) do
        {
          "data" =>
            "10.1371/journal.pone.0036790 2012-05-15 New Dromaeosaurids (Dinosauria: Theropoda) from the Lower Cretaceous of Utah, and the Evolution of the Dromaeosaurid Tail",
        }
      end

      it "JSON" do
        put uri, params, headers

        expect(last_response.status).to eq(422)
        error = json["errors"].first
        expect(error["status"]).to eq("422")
        expect(error["title"]).to start_with("Invalid payload")
        expect(json["data"]).to be_blank
      end
    end
  end

  context "show" do
    let(:doi) do
      allow_any_instance_of(DataciteDoi).to receive(:send_import_message)
      allow_any_instance_of(Doi).to receive(:send_import_message)
      create(:doi, client: client, aasm_state: "findable")
    end
    let(:source_doi) { create(:doi, client: client, aasm_state: "findable") }
    let!(:event) do
      create(
        :event_for_datacite_crossref,
        subj_id: "https://doi.org/#{doi.doi}",
        obj_id: "https://doi.org/#{source_doi.doi}",
        relation_type_id: "is-referenced-by",
      )
    end

    let(:uri) { "/events/#{event.uuid}?include=subj,obj" }

    before do
      DataciteDoi.import
      Event.import
      sleep 2
    end

    context "as admin user" do
      it "JSON" do
        get uri, nil, headers

        expect(last_response.status).to eq(200)
        expect(json.dig("data", "attributes", "relation-type-id")).to eq(
          "is-referenced-by",
        )
        expect(json.dig("data", "attributes", "subj-id")).to eq(
          "https://doi.org/#{doi.doi.downcase}",
        )
        expect(json.dig("data", "attributes", "obj-id")).to eq(
          "https://doi.org/#{source_doi.doi.downcase}",
        )
      end
    end

    context "as regular user" do
      let(:token) { User.generate_token(role_id: "user") }

      it "JSON" do
        get uri, nil, headers

        expect(last_response.status).to eq(200)
        expect(json.dig("data", "attributes", "relation-type-id")).to eq(
          "is-referenced-by",
        )
        expect(json.dig("data", "attributes", "subj-id")).to eq(
          "https://doi.org/#{doi.doi.downcase}",
        )
        expect(json.dig("data", "attributes", "obj-id")).to eq(
          "https://doi.org/#{source_doi.doi.downcase}",
        )
      end
    end

    context "event not found" do
      let(:uri) { "/events/#{event.uuid}x" }

      it "JSON" do
        get uri, nil, headers

        expect(last_response.status).to eq(404)
        expect(json["errors"]).to eq(
          [
            {
              "status" => "404",
              "title" => "The resource you are looking for doesn't exist.",
            },
          ],
        )
        expect(json["data"]).to be_nil
      end
    end
  end

  context "index" do
    #   # let!(:event) { create(:event) }
    #   # let(:uri) { "/events" }

    context "query by source-id by Crawler" do
      let(:uri) { "/events?query=datacite" }

      # Exclude the token header.
      let(:headers) do
        {
          "HTTP_ACCEPT" => "application/json",
          "HTTP_USER_AGENT" =>
            "Mozilla/5.0 (Linux; Android 6.0.1; Nexus 5X Build/MMB29P) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2272.96 Mobile Safari/537.36 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)",
        }
      end

      it "json" do
        get uri, nil, headers
        expect(last_response.status).to eq(404)
      end
    end

    context "query by source-id csv" do
      let!(:event) { create(:event) }
      let(:uri) { "/events" }
      let(:headers) do
        { "HTTP_ACCEPT" => "text/csv" }
      end

      before do
        Event.import
        sleep 2
      end

      it "text/csv" do
        get uri, nil, headers

        expect(last_response.status).to eq(200)
        lines = last_response.body.split("\n")
        expect(lines[0]).to eq("subj-id,obj-id,source-id,relation-type-id,occurred_at")
        expect(lines[1]).to start_with("#{event.subj_id},#{event.obj_id}")
      end
    end
  end

  # context "destroy" do
  #   let(:event) { create(:event) }
  #   let(:uri) { "/events/#{event.uuid}" }

  #   context "as admin user" do
  #     it "JSON" do
  #       delete uri, nil, headers
  #       expect(last_response.status).to eq(204)
  #       expect(last_response.body).to be_blank
  #     end
  #   end

  #   # context "as staff user" do
  #   #   let(:token) { User.generate_token(role_id: "staff_user") }

  #   #   it "JSON" do
  #   #     delete uri, nil, headers
  #   #     expect(last_response.status).to eq(401)

  #   #     response = JSON.parse(last_response.body)
  #   #     expect(response["errors"]).to eq(errors)
  #   #     expect(response["data"]).to be_nil
  #   #   end
  #   # end

  #   # context "as regular user" do
  #   #   let(:token) { User.generate_token(role_id: "user") }

  #   #   it "JSON" do
  #   #     delete uri, nil, headers
  #   #     expect(last_response.status).to eq(401)

  #   #     response = JSON.parse(last_response.body)
  #   #     expect(response["errors"]).to eq(errors)
  #   #     expect(response["data"]).to be_nil
  #   #   end
  #   # end

  #   # context "with wrong API key" do
  #   #   let(:headers) do
  #   #     { "HTTP_ACCEPT" => "application/json",
  #   #       "HTTP_AUTHORIZATION" => "Token token=12345678" }
  #   #   end

  #   #   it "JSON" do
  #   #     delete uri, nil, headers
  #   #     expect(last_response.status).to eq(401)

  #   #     response = JSON.parse(last_response.body)
  #   #     expect(response["errors"]).to eq(errors)
  #   #     expect(response["data"]).to be_nil
  #   #   end
  #   # end

  #   context "event not found" do
  #     let(:uri) { "/events/#{event.uuid}x" }

  #     it "JSON" do
  #       delete uri, nil, headers
  #       expect(last_response.status).to eq(404)
  #       expect(json["errors"]).to eq([{ "status" => "404", "title" => "The resource you are looking for doesn't exist." }])
  #       expect(json["data"]).to be_nil
  #     end
  #   end
  # end
end
