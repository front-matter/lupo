module Helpable
  extend ActiveSupport::Concern

  require 'bolognese'
  require 'securerandom'
  require 'base32/url'

  UPPER_LIMIT = 1073741823

  included do
    include Bolognese::Utils
    include Bolognese::DoiUtils

    def register_url
      logger = Logger.new(STDOUT)

      unless url.present?
        logger.error "[Handle] Error updating DOI " + doi + ": url missing."
        return OpenStruct.new(body: { "errors" => [{ "title" => "URL missing." }] })
      end

      unless client_id.present?
        logger.error "[Handle] Error updating DOI " + doi + ": client ID missing."
        return OpenStruct.new(body: { "errors" => [{ "title" => "Client ID missing." }] })
      end

      unless is_registered_or_findable?
        return OpenStruct.new(body: { "errors" => [{ "title" => "DOI is not registered or findable." }] })
      end

      payload = [
        {
          "index" => 100,
          "type" => "HS_ADMIN",
          "data" => {
            "format" => "admin",
            "value" => {
              "handle" => ENV['HANDLE_USERNAME'],
              "index" => 300,
              "permissions" => "111111111111"
            }
          }
        },
        {
          "index" => 1,
          "type" => "URL",
          "data" => {
            "format" => "string",
            "value" => url
          }
        }
      ].to_json

      handle_url = "#{ENV['HANDLE_URL']}/api/handles/#{doi}"
      response = Maremma.put(handle_url, content_type: 'application/json;charset=UTF-8', data: payload, username: "300%3A#{ENV['HANDLE_USERNAME']}", password: ENV['HANDLE_PASSWORD'], ssl_self_signed: true, timeout: 10)

      if [200, 201].include?(response.status)
        # update minted column after first successful registration in handle system
        self.update_columns(minted: Time.zone.now, updated: Time.zone.now) if minted.blank?
        logger.info "[Handle] URL for DOI " + doi + " updated to " + url + "."

        response
      else
        logger.error "[Handle] Error updating URL for DOI " + doi + ": " + response.body.inspect
        response
      end
    end

    def get_url
      url = "#{ENV['HANDLE_URL']}/api/handles/#{doi}?index=1"
      response = Maremma.get(url, ssl_self_signed: true, timeout: 10)

      if response.status == 200
        response
      else
        logger = Logger.new(STDOUT)
        logger.error "[Handle] Error fetching URL for DOI " + doi + ": " + response.body.inspect
        response
      end
    end

    def generate_random_doi(str, options={})
      prefix = validate_prefix(str)
      fail IdentifierError, "No valid prefix found" unless prefix.present?

      shoulder = str.split("/", 2)[1].to_s
      encode_doi(prefix, shoulder: shoulder, number: options[:number])
    end

    def encode_doi(prefix, options={})
      prefix = validate_prefix(prefix)
      return nil unless prefix.present?

      number = options[:number].to_s.scan(/\d+/).join("").to_i
      number = SecureRandom.random_number(UPPER_LIMIT) unless number > 0
      shoulder = options[:shoulder].to_s
      shoulder += "-" if shoulder.present?
      length = 8
      split = 4
      prefix.to_s + "/" + shoulder + Base32::URL.encode(number, split: split, length: length, checksum: true)
    end

    def epoch_to_utc(epoch)
      Time.at(epoch).to_datetime.utc.iso8601
    end
  end

  module ClassMethods
    def get_dois(options={})
      return OpenStruct.new(body: { "errors" => [{ "title" => "Prefix missing" }] }) unless options[:prefix].present?

      url = "#{ENV['HANDLE_URL']}/api/handles?prefix=#{options[:prefix]}"
      response = Maremma.get(url, username: "300%3A#{ENV['HANDLE_USERNAME']}", password: ENV['HANDLE_PASSWORD'], ssl_self_signed: true, timeout: 10)

      if response.status == 200
        response
      else
        text = "Error " + response.body["errors"].inspect

        logger = Logger.new(STDOUT)
        logger.error "[Handle] " + text
        User.send_notification_to_slack(text, title: "Error #{response.status.to_s}", level: "danger") unless Rails.env.test?
        response
      end
    end
  end
end
