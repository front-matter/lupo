# frozen_string_literal: true

class FunderType < BaseObject
  implements ActorItem

  description "Information about funders"

  field :address, AddressType, null: true, description: "Physical address of the funder."
  field :view_count, Integer, null: true, description: "The number of views according to the Counter Code of Practice."
  field :download_count, Integer, null: true, description: "The number of downloads according to the Counter Code of Practice."
  field :citation_count, Integer, null: true, description: "The number of citations."

  field :datasets, DatasetConnectionWithTotalType, null: true, description: "Funded datasets", connection: true do
    argument :query, String, required: false
    argument :ids, [String], required: false
    argument :user_id, String, required: false
    argument :repository_id, String, required: false
    argument :member_id, String, required: false
    argument :has_person, Boolean, required: false
    argument :has_organization, Boolean, required: false
    argument :has_citations, Int, required: false
    argument :has_parts, Int, required: false
    argument :has_versions, Int, required: false
    argument :has_views, Int, required: false
    argument :has_downloads, Int, required: false
    argument :first, Int, required: false, default_value: 25, as: :size
    argument :after, String, required: false, as: :cursor
  end

  field :publications, PublicationConnectionWithTotalType, null: true, description: "Funded publications", connection: true do
    argument :query, String, required: false
    argument :ids, [String], required: false
    argument :user_id, String, required: false
    argument :repository_id, String, required: false
    argument :member_id, String, required: false
    argument :has_person, Boolean, required: false
    argument :has_organization, Boolean, required: false
    argument :has_citations, Int, required: false
    argument :has_parts, Int, required: false
    argument :has_versions, Int, required: false
    argument :has_views, Int, required: false
    argument :has_downloads, Int, required: false
    argument :first, Int, required: false, default_value: 25, as: :size
    argument :after, String, required: false, as: :cursor
  end

  field :softwares, SoftwareConnectionWithTotalType, null: true, description: "Funded software", connection: true do
    argument :query, String, required: false
    argument :ids, [String], required: false
    argument :user_id, String, required: false
    argument :repository_id, String, required: false
    argument :member_id, String, required: false
    argument :has_person, Boolean, required: false
    argument :has_organization, Boolean, required: false
    argument :has_citations, Int, required: false
    argument :has_parts, Int, required: false
    argument :has_versions, Int, required: false
    argument :has_views, Int, required: false
    argument :has_downloads, Int, required: false
    argument :first, Int, required: false, default_value: 25, as: :size
    argument :after, String, required: false, as: :cursor
  end

  field :works, WorkConnectionWithTotalType, null: true, description: "Funded works", connection: true do
    argument :query, String, required: false
    argument :ids, [String], required: false
    argument :user_id, String, required: false
    argument :repository_id, String, required: false
    argument :member_id, String, required: false
    argument :affiliation_id, String, required: false
    argument :resource_type_id, String, required: false
    argument :has_person, Boolean, required: false
    argument :has_organization, Boolean, required: false
    argument :has_citations, Int, required: false
    argument :has_parts, Int, required: false
    argument :has_versions, Int, required: false
    argument :has_views, Int, required: false
    argument :has_downloads, Int, required: false
    argument :first, Int, required: false, default_value: 25, as: :size
    argument :after, String, required: false, as: :cursor
  end

  def address
    { "type" => "postalAddress",
      "country" => object.country.to_h.fetch("name", nil) }
  end

  def publications(**args)
    args[:resource_type_id] = "Text"
    response(args)
  end

  def datasets(**args)
    args[:resource_type_id] = "Dataset"
    response(args)
  end

  def softwares(**args)
    args[:resource_type_id] = "Software"
    response(args)
  end

  def works(**args)
    response(args)
  end

  def view_count
    args = { first: 0 }
    r = response(args)
    r.results.total.positive? ? aggregate_count(r.response.aggregations.views.buckets) : 0
  end

  def download_count
    args = { first: 0 }
    r = response(args)
    r.results.total.positive? ? aggregate_count(r.response.aggregations.downloads.buckets) : 0
  end

  def citation_count
    args = { first: 0 }
    r = response(args)
    r.results.total.positive? ? aggregate_count(r.response.aggregations.citations.buckets) : 0
  end

  def response(**args)
    Doi.query(args[:query], ids: args[:ids], funder_id: object.id, user_id: args[:user_id], client_id: args[:repository_id], provider_id: args[:member_id], affiliation_id: args[:affiliation_id], resource_type_id: args[:resource_type_id], has_person: args[:has_person], has_organization: args[:has_organization], has_citations: args[:has_citations], has_parts: args[:has_parts], has_versions: args[:has_versions], has_views: args[:has_views], has_downloads: args[:has_downloads], state: "findable", page: { cursor: args[:cursor].present? ? Base64.urlsafe_decode64(args[:cursor]) : nil, size: args[:size] })
  end
end
