class PrefixResource < JSONAPI::Resource
  attributes  :created, :prefix, :version
  has_many :datacentres
  has_many :allocators
end
