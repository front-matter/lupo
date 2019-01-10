class ClientsController < ApplicationController
  include Countable

  before_action :set_client, only: [:show, :update, :destroy]
  before_action :authenticate_user!
  before_action :set_include
  load_and_authorize_resource :except => [:index, :show]

  def index
    sort = case params[:sort]
           when "relevance" then { "_score" => { order: 'desc' }}
           when "name" then { "name.raw" => { order: 'asc' }}
           when "-name" then { "name.raw" => { order: 'desc' }}
           when "created" then { created: { order: 'asc' }}
           when "-created" then { created: { order: 'desc' }}
           else { "name.raw" => { order: 'asc' }}
           end

    page = page_from_params(params)

    if params[:id].present?
      response = Client.find_by_id(params[:id]) 
    elsif params[:ids].present?
      response = Client.find_by_ids(params[:ids], page: page, sort: sort)
    else
      response = Client.query(params[:query], year: params[:year], provider_id: params[:provider_id], software: params[:software], page: page, sort: sort)
    end

    begin
      total = response.results.total
      total_pages = page[:size] > 0 ? (total.to_f / page[:size]).ceil : 0
      years = total > 0 ? facet_by_year(response.response.aggregations.years.buckets) : nil
      providers = total > 0 ? facet_by_provider(response.response.aggregations.providers.buckets) : nil
      software = total > 0 ? facet_by_software(response.response.aggregations.software.buckets) : nil

      @clients = response.results.results

      options = {}
      options[:meta] = {
        total: total,
        "totalPages" => total_pages,
        page: page[:number],
        years: years,
        providers: providers,
        software: software
      }.compact

      options[:links] = {
        self: request.original_url,
        next: @clients.blank? ? nil : request.base_url + "/clients?" + {
          query: params[:query],
          "provider-id" => params[:provider_id],
          software: params[:software],
          year: params[:year],
          fields: params[:fields],
          "page[number]" => page[:number] + 1,
          "page[size]" => page[:size],
          sort: params[:sort] }.compact.to_query
        }.compact
      options[:include] = @include
      options[:is_collection] = true

      render json: ClientSerializer.new(@clients, options).serialized_json, status: :ok
    rescue Elasticsearch::Transport::Transport::Errors::BadRequest => exception
      Bugsnag.notify(exception)

      message = JSON.parse(exception.message[6..-1]).to_h.dig("error", "root_cause", 0, "reason")

      render json: { "errors" => { "title" => message }}.to_json, status: :bad_request
    end
  end

  def show
    options = {}
    options[:meta] = { dois: doi_count(client_id: params[:id]) }
    options[:include] = @include
    options[:is_collection] = false

    render json: ClientSerializer.new(@client, options).serialized_json, status: :ok
  end

  def create
    logger = Logger.new(STDOUT)
    @client = Client.new(safe_params)
    authorize! :create, @client

    if @client.save
      options = {}
      options[:is_collection] = false
  
      render json: ClientSerializer.new(@client, options).serialized_json, status: :created
    else
      logger.warn @client.errors.inspect
      render json: serialize(@client.errors), status: :unprocessable_entity
    end
  end

  def update
    logger = Logger.new(STDOUT)
    if @client.update_attributes(safe_params)
      options = {}
      options[:meta] = { dois: doi_count(client_id: params[:id]) }
      options[:is_collection] = false
  
      render json: ClientSerializer.new(@client, options).serialized_json, status: :ok
    else
      logger.warn @client.errors.inspect
      render json: serialize(@client.errors), status: :unprocessable_entity
    end
  end

  # don't delete, but set deleted_at timestamp
  # a client with dois or prefixes can't be deleted
  def destroy
    logger = Logger.new(STDOUT)
    if @client.dois.present?
      message = "Can't delete client that has DOIs."
      status = 400
      logger.warn message
      render json: { errors: [{ status: status.to_s, title: message }] }.to_json, status: status
    elsif @client.update_attributes(is_active: nil, deleted_at: Time.zone.now)
      @client.send_delete_email unless Rails.env.test?
      head :no_content
    else
      logger.warn @client.errors.inspect
      render json: serialize(@client.errors), status: :unprocessable_entity
    end
  end

  def totals
    page = { size: 25, number: 1 }
    page_prov = { size: 2000, number: 1 }

    ttl = Client.query("", page: page_prov).map do |client|    
      response = Doi.query("", client_id: client.symbol.downcase, page: page)
      total = response.results.total
      states = total > 0 ? facet_by_key(response.response.aggregations.states.buckets) : nil
      temporal ={}
      temporal[:this_month] = total > 0 ? facet_by_date(response.response.aggregations.this_month.buckets) : nil
      temporal[:this_year] = total > 0 ? facet_anual(response.response.aggregations.this_year.buckets) : nil
      temporal[:last_year] = total > 0 ? facet_anual(response.response.aggregations.last_year.buckets) : nil
      id = client.symbol
      {id: id, title: id, count: total, states: states, temporal: temporal}
    end
    render json: ttl, status: :ok
  end

  protected

  def set_include
    if params[:include].present?
      @include = params[:include].split(",").map { |i| i.downcase.underscore.to_sym }
      @include = @include & [:provider, :repository]
    else
      @include = [:provider, :repository]
    end
  end

  def set_client
    @client = Client.where(symbol: params[:id]).where(deleted_at: nil).first
    fail ActiveRecord::RecordNotFound unless @client.present?
  end

  private

  def safe_params
    fail JSON::ParserError, "You need to provide a payload following the JSONAPI spec" unless params[:data].present?
    ActiveModelSerializers::Deserialization.jsonapi_parse!(
      params, only: [:symbol, :name, "contactName", "contactEmail", :domains, :provider, :url, :repository, :description, :software, "targetId", "isActive", "passwordInput"],
              keys: { "contactName" => :contact_name, "contactEmail" => :contact_email, "targetId" => :target_id, "isActive" => :is_active, "passwordInput" => :password_input }
    )
  end
end
