# frozen_string_literal: true

class V3::ProvidersController < ApplicationController
  include ActionController::MimeResponds
  include Countable

  prepend_before_action :authenticate_user!
  before_action :set_provider, only: %i[show update destroy stats]
  before_action :set_include
  load_and_authorize_resource only: %i[update destroy]

  def index
    sort =
      case params[:sort]
      when "relevance"
        { "_score" => { order: "desc" } }
      when "name"
        { "display_name.raw" => { order: "asc" } }
      when "-name"
        { "display_name.raw" => { order: "desc" } }
      when "created"
        { created: { order: "asc" } }
      when "-created"
        { created: { order: "desc" } }
      else
        { "display_name.raw" => { order: "asc" } }
      end

    page = page_from_params(params)

    response = if params[:id].present?
      Provider.find_by_id(params[:id])
    elsif params[:ids].present?
      Provider.find_by_id(params[:ids], page: page, sort: sort)
    else
      Provider.query(
        params[:query],
        year: params[:year],
        from_date: params[:from_date],
        until_date: params[:until_date],
        region: params[:region],
        consortium_id: params[:consortium_id],
        member_type: params[:member_type],
        organization_type: params[:organization_type],
        focus_area: params[:focus_area],
        non_profit_status: params[:non_profit_status],
        page: page,
        sort: sort,
      )
    end

    begin
      total = response.results.total
      total_pages = page[:size] > 0 ? (total.to_f / page[:size]).ceil : 0

      years =
        if total > 0
          facet_by_key_as_string(response.response.aggregations.years.buckets)
        end
      regions =
        if total > 0
          facet_by_region(response.response.aggregations.regions.buckets)
        end
      member_types =
        if total > 0
          facet_by_key(response.response.aggregations.member_types.buckets)
        end
      organization_types =
        if total > 0
          facet_by_key(
            response.response.aggregations.organization_types.buckets,
          )
        end
      focus_areas =
        if total > 0
          facet_by_key(response.response.aggregations.focus_areas.buckets)
        end
      non_profit_statuses =
        if total > 0
          facet_by_key(
            response.response.aggregations.non_profit_statuses.buckets,
          )
        end

      @providers = response.results
      respond_to do |format|
        format.json do
          options = {}
          options[:meta] = {
            total: total,
            "totalPages" => total_pages,
            page: page[:number],
            years: years,
            regions: regions,
            "memberTypes" => member_types,
            "organizationTypes" => organization_types,
            "focusAreas" => focus_areas,
            "nonProfitStatuses" => non_profit_statuses,
          }.compact

          options[:links] = {
            self: request.original_url,
            next:
              if @providers.blank?
                nil
              else
                request.base_url + "/providers?" +
                  {
                    query: params[:query],
                    year: params[:year],
                    region: params[:region],
                    "member_type" => params[:member_type],
                    "organization_type" => params[:organization_type],
                    "focus-area" => params[:focus_area],
                    "non-profit-status" => params[:non_profit_status],
                    "page[number]" => page[:number] + 1,
                    "page[size]" => page[:size],
                    sort: sort,
                  }.compact.
                  to_query
              end,
          }.compact
          options[:include] = @include
          options[:is_collection] = true
          options[:params] = { current_ability: current_ability }

          fields = fields_from_params(params)
          if fields
            render json:
                     ProviderSerializer.new(
                       @providers,
                       options.merge(fields: fields),
                     ).
                       serialized_json,
                   status: :ok
          else
            render json:
            V3::ProviderSerializer.new(@providers, options).
                       serialized_json,
                   status: :ok
          end
        end
        header = %w[
          accountName
          fabricaAccountId
          year
          is_active
          accountDescription
          accountWebsite
          region
          country
          logo_url
          focusArea
          organisation_type
          accountType
          generalContactEmail
          groupEmail
          technicalContactEmail
          technicalContactGivenName
          technicalContactFamilyName
          secondaryTechnicalContactEmail
          secondaryTechnicalContactGivenName
          secondaryTechnicalContactFamilyName
          serviceContactEmail
          serviceContactGivenName
          serviceContactFamilyName
          secondaryServiceContactEmail
          secondaryServiceContactGivenName
          secondaryServiceContactFamilyName
          votingContactEmail
          votingContactGivenName
          votingContactFamilyName
          billingStreet
          billingPostalCode
          billingCity
          department
          billingOrganization
          billingState
          billingCountry
          billingContactEmail
          billingContactGivenName
          billingontactFamilyName
          secondaryBillingContactEmail
          secondaryBillingContactGivenName
          secondaryBillingContactFamilyName
          twitter
          ror_id
          member_type
          joined
          created
          updated
          deleted_at
        ]
        format.csv do
          render request.format.to_sym => response.records.to_a, header: header
        end
      end
    rescue Elasticsearch::Transport::Transport::Errors::BadRequest => e
      Raven.capture_exception(e)

      message =
        JSON.parse(e.message[6..-1]).to_h.dig(
          "error",
          "root_cause",
          0,
          "reason",
        )

      render json: { "errors" => { "title" => message } }.to_json,
             status: :bad_request
    end
  end

  def show
    options = {}
    if @provider.member_type == "consortium"
      options[:meta] = {
        "consortiumOrganizationCount" =>
          Array.wrap(@provider.consortium_organization_ids).length,
      }
    elsif %w[direct_member consortium_organization].include?(
      @provider.member_type,
    )
      options[:meta] = {
        "repositoryCount" => Array.wrap(@provider.client_ids).length,
      }
    end

    options[:include] = @include
    options[:is_collection] = false
    options[:params] = { current_ability: current_ability }

    render json: V3::ProviderSerializer.new(@provider, options).serialized_json,
           status: :ok
  end

  def create
    # generate random symbol if no symbol is provided
    @provider =
      Provider.new(
        safe_params.reverse_merge(symbol: generate_random_provider_symbol),
      )
    authorize! :create, @provider

    if @provider.save
      @provider.send_welcome_email(responsible_id: current_user.uid)
      options = {}
      options[:include] = @include
      options[:is_collection] = false
      options[:params] = { current_ability: current_ability }

      render json: V3::ProviderSerializer.new(@provider, options).serialized_json,
             status: :ok
    else
      # Rails.logger.error @provider.errors.inspect
      render json: serialize_errors(@provider.errors, uid: @provider.uid),
             status: :unprocessable_entity
    end
  end

  def update
    if @provider.update(safe_params)
      options = {}
      options[:include] = @include
      options[:is_collection] = false
      options[:params] = { current_ability: current_ability }

      render json: V3::ProviderSerializer.new(@provider, options).serialized_json,
             status: :ok
    else
      # Rails.logger.error @provider.errors.inspect
      render json: serialize_errors(@provider.errors, uid: @provider.uid),
             status: :unprocessable_entity
    end
  end

  # don't delete, but set deleted_at timestamp
  # a provider with active clients or with prefixes can't be deleted
  def destroy
    if active_client_count(provider_id: @provider.symbol).positive?
      message = "Can't delete provider that has active clients."
      status = 400
      Rails.logger.warn message
      render json: {
        errors: [{ status: status.to_s, title: message }],
      }.to_json,
             status: status
    elsif @provider.update(is_active: nil, deleted_at: Time.zone.now)
      unless Rails.env.test?
        @provider.send_delete_email(responsible_id: current_user.uid)
      end
      head :no_content
    else
      # Rails.logger.error @provider.errors.inspect
      render json: serialize_errors(@provider.errors, uid: @provider.uid),
             status: :unprocessable_entity
    end
  end

  def random
    symbol = generate_random_provider_symbol
    render json: { symbol: symbol }.to_json
  end

  def totals
    page = { size: 0, number: 1 }

    state =
      if current_user.present? && current_user.is_admin_or_staff? &&
          params[:state].present?
        params[:state]
      else
        "registered,findable"
      end
    response =
      DataciteDoi.query(nil, state: state, page: page, totals_agg: "provider")
    registrant =
      providers_totals(response.response.aggregations.providers_totals.buckets)

    render json: registrant, status: :ok
  end

  def stats
    if params[:id] == "admin"
      providers = provider_count(consortium_id: nil)
      clients = client_count(provider_id: nil)
      dois = doi_count(provider_id: nil)
      # resource_types = resource_type_count(provider_id: nil)
      # citations = nil # citation_count(provider_id: nil)
      # views = nil # view_count(provider_id: nil)
      # downloads = nil # download_count(provider_id: nil)
    elsif @provider.member_type == "consortium"
      providers = provider_count(consortium_id: params[:id])
      clients = client_count(consortium_id: params[:id])
      dois = doi_count(consortium_id: params[:id])
      # resource_types = resource_type_count(consortium_id: params[:id])
      # citations = citation_count(consortium_id: params[:id])
      # views = view_count(consortium_id: params[:id])
      # downloads = download_count(consortium_id: params[:id])
    else
      providers = nil
      clients = client_count(provider_id: params[:id])
      dois = doi_count(provider_id: params[:id])
      # resource_types = resource_type_count(provider_id: params[:id])
      # citations = citation_count(provider_id: params[:id])
      # views = view_count(provider_id: params[:id])
      # downloads = download_count(provider_id: params[:id])
    end

    meta = {
      # downloads: downloads,
      providers: providers,
      clients: clients,
      dois: dois,
    }.compact

    render json: meta, status: :ok
  end

  protected
    def set_include
      if params[:include].present?
        @include =
          params[:include].split(",").map { |i| i.downcase.underscore.to_sym }
        @include = @include & %i[consortium consortium_organizations contacts]
      else
        @include = []
      end
    end

    def set_provider
      @provider =
        Provider.unscoped.where(
          "allocator.role_name IN ('ROLE_FOR_PROFIT_PROVIDER', 'ROLE_CONTRACTUAL_PROVIDER', 'ROLE_CONSORTIUM' , 'ROLE_CONSORTIUM_ORGANIZATION', 'ROLE_ALLOCATOR', 'ROLE_ADMIN', 'ROLE_MEMBER', 'ROLE_REGISTRATION_AGENCY')",
        ).
          where(deleted_at: nil).
          where(symbol: params[:id]).
          first
      fail ActiveRecord::RecordNotFound if @provider.blank?
    end

  private
    def safe_params
      if params[:data].blank?
        fail JSON::ParserError,
             "You need to provide a payload following the JSONAPI spec"
      end

      ActiveModelSerializers::Deserialization.jsonapi_parse!(
        params,
        only: [
          :name,
          "displayName",
          :symbol,
          :logo,
          :description,
          :website,
          :joined,
          "globusUuid",
          "organizationType",
          "focusArea",
          :consortium,
          "systemEmail",
          "groupEmail",
          "isActive",
          "passwordInput",
          :country,
          "billingInformation",
          {
            "billingInformation": [
              "postCode",
              :state,
              :city,
              :address,
              :department,
              :organization,
              :country,
            ],
          },
          "rorId",
          "twitterHandle",
          "memberType",
          "nonProfitStatus",
          "salesforceId",
          "technicalContact",
          { "technicalContact": [:email, "givenName", "familyName"] },
          "secondaryTechnicalContact",
          { "secondaryTechnicalContact": [:email, "givenName", "familyName"] },
          "secondaryBillingContact",
          { "secondaryBillingContact": [:email, "givenName", "familyName"] },
          "billingContact",
          { "billingContact": [:email, "givenName", "familyName"] },
          "serviceContact",
          { "serviceContact": [:email, "givenName", "familyName"] },
          "secondaryServiceContact",
          { "secondaryServiceContact": [:email, "givenName", "familyName"] },
          "votingContact",
          { "votingContact": [:email, "givenName", "familyName"] },
        ],
        keys: {
          "displayName" => :display_name,
          "organizationType" => :organization_type,
          "focusArea" => :focus_area,
          country: :country_code,
          "isActive" => :is_active,
          "passwordInput" => :password_input,
          "billingInformation" => :billing_information,
          "postCode" => :post_code,
          "rorId" => :ror_id,
          "twitterHandle" => :twitter_handle,
          "memberType" => :member_type,
          "technicalContact" => :technical_contact,
          "secondaryTechnicalContact" => :secondary_technical_contact,
          "secondaryBillingContact" => :secondary_billing_contact,
          "billingContact" => :billing_contact,
          "serviceContact" => :service_contact,
          "secondaryServiceContact" => :secondary_service_contact,
          "votingContact" => :voting_contact,
          "groupEmail" => :group_email,
          "systemEmail" => :system_email,
          "nonProfitStatus" => :non_profit_status,
          "salesforceId" => :salesforce_id,
          "globusUuid" => :globus_uuid,
        },
      )
    end
end