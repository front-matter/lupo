# frozen_string_literal: true

class DataCatalogType < BaseObject
  description "A collection of datasets."

  field :id, ID, null: false, description: "The ID of the data catalog."
  field :type, String, null: false, description: "The type of the item."
  field :identifier, [IdentifierType], null: true, description: "re3data ID"
  field :name, String, null: true, description: "The name of the data catalog."
  field :alternate_name, [String], null: true, description: "An alias for the data catalog."
  field :url, String, null: true, hash_key: "repositoryUrl", description: "URL of the data catalog."
  field :contacts, [String], null: true, description: "Repository contact information"
  field :description, String, null: true, description: "A description of the data catalog."
  field :certificates, [DefinedTermType], null: true, description: "Certificates of the data catalog."
  field :subjects, [DefinedTermType], null: true, description: "Subject areas covered by the data catalog."
  # field :types, [String], null: true, description: "Repository types"
  # field :content_types, [SchemeType], null: true, description: "Content types"
  field :provider_types, [String], null: true, description: "Provider types"
  field :in_language, [String], null: true, description: "The language of the content of the data catalog."
  field :keywords, String, null: true, description: "Keywords or tags used to describe this data catalog. Multiple entries in a keywords list are typically delimited by commas."
  field :data_accesses, [TextRestrictionType], null: true, description: "Data accesses"
  field :data_uploads, [TextRestrictionType], null: true, description: "Data uploads"
  field :pid_systems, [String], null: true, description: "PID Systems"
  # field :apis, [ApiType], null: true, description: "APIs"
  field :software_application, [SoftwareApplicationType], null: true, description: "Software"
  field :view_count, Integer, null: true, description: "The number of views according to the Counter Code of Practice."
  field :download_count, Integer, null: true, description: "The number of downloads according to the Counter Code of Practice."
  field :citation_count, Integer, null: true, description: "The number of citations."

  field :datasets, DatasetConnectionWithTotalType, null: true, description: "Funded datasets", connection: true do
    argument :query, String, required: false
    argument :user_id, String, required: false
    argument :repository_id, String, required: false
    argument :member_id, String, required: false
    argument :has_citations, Int, required: false
    argument :has_parts, Int, required: false
    argument :has_versions, Int, required: false
    argument :has_views, Int, required: false
    argument :has_downloads, Int, required: false
    argument :first, Int, required: false, default_value: 25
  end

  def identifier
    Array.wrap(object.re3data_id).map { |o| { "name" => "re3data", "value" => "r3d#{o}" } }
  end

  def alternate_name
    Array.wrap(object["additional_names"]).map { |n| n["text"] }
  end

  def keywords
    Array.wrap(object.keywords).map { |k| k["text"] }.join(", ")
  end

  def in_language
    Array.wrap(object.repository_languages).map { |k| k["text"] }
  end

  def certificates
    Array.wrap(object.certificates).map { |s| { "name" => s["text"] } }
  end

  def subjects
    Array.wrap(object.subjects).map do |s|
      term_code, name = s["text"].split(" ", 2)

      {
        "term_code" => term_code,
        "name" => name,
        "in_defined_term_set" => "DFG" }
    end
  end

  def software_application
    Array.wrap(object.software).map { |s| { "name" => s["name"] } }
  end

  def datasets(**args)
    Doi.query(args[:query], re3data_id: object[:id], user_id: args[:user_id], client_id: args[:repository_id], provider_id: args[:member_id], has_citations: args[:has_citations], has_parts: args[:has_parts], has_versions: args[:has_versions], has_views: args[:has_views], has_downloads: args[:has_downloads], resource_type_id: "Dataset", state: "findable", page: { number: 1, size: args[:first] })
  end

  def view_count
    response.results.total.positive? ? aggregate_count(response.response.aggregations.views.buckets) : 0
  end

  def download_count
    response.results.total.positive? ? aggregate_count(response.response.aggregations.downloads.buckets) : 0
  end

  def citation_count
    response.results.total.positive? ? aggregate_count(response.response.aggregations.citations.buckets) : 0
  end

  def response
    @response ||= Doi.query(nil, re3data_id: object[:id], state: "findable", page: { number: 1, size: 0 })
  end
end
