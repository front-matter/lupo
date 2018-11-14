class ProviderPrefixSerializer
  include FastJsonapi::ObjectSerializer
  set_key_transform :camel_lower
  set_type "provider-prefixes"
  set_id :uid
  attributes :created, :updated

  belongs_to :provider, record_type: :providers
  belongs_to :prefix, record_type: :prefixes
  has_many :clients, record_type: :clients
end
