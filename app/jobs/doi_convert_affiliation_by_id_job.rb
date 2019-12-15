class DoiConvertAffiliationByIdJob < ActiveJob::Base
  queue_as :lupo_background

  rescue_from ActiveJob::DeserializationError, Elasticsearch::Transport::Transport::Errors::BadRequest do |error|
    Rails.logger.error error.message
  end

  def perform(options={})
    Doi.convert_affiliation_by_id(options)
  end
end
