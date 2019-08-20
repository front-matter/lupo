class AffiliationJob < ActiveJob::Base
  queue_as :lupo_background

  def perform(doi_id)
    logger = Logger.new(STDOUT)
    doi = Doi.where(doi: doi_id).first

    if doi.present?
      new_creators = Array.wrap(doi.creators).map do |c|
        c["affiliation"] = { "name" => c["affiliation"] } if c["affiliation"].is_a?(String)
        c
      end
      new_contributors = Array.wrap(doi.contributors).map do |c|
        c["affiliation"] = { "name" => c["affiliation"] } if c["affiliation"].is_a?(String)
        c
      end
      doi.update_attributes(creators: new_creators, contributors: new_contributors)

      doi.__elasticsearch__.index_document
    else
      logger.info "[Affiliation] Error updaing DOI " + doi_id + ": not found"
    end
  end
end