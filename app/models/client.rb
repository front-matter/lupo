class Client < ActiveRecord::Base

  # include helper module for caching infrequently changing resources
  include Cacheable

  # include helper module for counting registered DOIs
  include Countable

  # define table and attribute names
  # uid is used as unique identifier, mapped to id in serializer
  self.table_name = "datacentre"

  alias_attribute :created_at, :created
  alias_attribute :updated_at, :updated

  delegate :symbol, to: :provider, prefix: true

  validates_presence_of :symbol, :name, :contact_email
  validates_uniqueness_of :symbol, message: "This Client ID has already been taken"
  validates_format_of :contact_email, :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i
  validates_numericality_of :doi_quota_allowed, :doi_quota_used
  validates_numericality_of :version, if: :version?
  validates_inclusion_of :role_name, :in => %w( ROLE_DATACENTRE ), :message => "Role %s is not included in the list"
  validate :check_id, :on => :create
  validate :freeze_uid, :on => :update
  belongs_to :provider, foreign_key: :allocator
  has_many :datasets, foreign_key: :datacentre
  has_many :client_prefixes, foreign_key: :datacentre
  has_many :prefixes, through: :client_prefixes

  before_validation :set_defaults
  before_create :set_test_prefix
  before_create { self.created = Time.zone.now.utc.iso8601 }
  before_save { self.updated = Time.zone.now.utc.iso8601 }

  default_scope { where(deleted_at: nil) }

  scope :query, ->(query) { where("datacentre.symbol like ? OR datacentre.name like ?", "%#{query}%", "%#{query}%") }

  def uid
    symbol.downcase
  end

  # workaround for non-standard database column names and association
  def provider_id
    provider_symbol.downcase
  end

  def provider_id=(value)
    r = cached_provider_response(value)
    fail ActiveRecord::RecordNotFound unless r.present?

    write_attribute(:allocator, r.id)
  end

  # backwards compatibility
  def member
    m = cached_member_response(provider_id)
    m[:data] if m.present?
  end

  def year
    created_at.year if created_at.present?
  end

  def query_filter
    "datacentre_symbol:#{symbol}"
  end

  def doi_quota_exceeded
    unless doi_quota_allowed.to_i > 0
      errors.add(:doi_quota, "You have excceded your DOI quota. You cannot mint DOIs anymore")
    end
  end

  def freeze_uid
    errors.add(:uid, "cannot be changed") if self.uid_changed? || self.symbol_changed?
  end

  def check_id
    errors.add(:id, ", Your Client ID must include the name of your provider. Separated by a dot '.' ") if self.symbol.split(".")[0].downcase != self.provider.symbol.downcase
  end

  private

  def set_test_prefix
    return if prefixes.where(prefix: "10.5072").first

    prefixes << cached_prefix_response("10.5072")
  end

  def set_defaults
    self.contact_name = "" unless contact_name.present?
    self.is_active = is_active? ? "\x01" : "\x00"
    self.role_name = "ROLE_DATACENTRE" unless role_name.present?
    self.doi_quota_used = 0 unless doi_quota_used.to_i > 0
    self.doi_quota_allowed = -1 unless doi_quota_allowed.to_i > 0
  end
end
