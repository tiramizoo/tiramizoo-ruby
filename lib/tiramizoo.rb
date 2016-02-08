require "tiramizoo/version"
require 'excon'

module Tiramizoo
  class Api
    class InvalidApiToken               < StandardError; end
    class ServerError                   < StandardError; end
    class UnprocessableEntity           < StandardError; end
    class ServerIsUndergoingMaintenance < StandardError; end
    class UnknownError                  < StandardError; end

    attr_reader :connection, :api_token

    def initialize(api_token)
      @api_token  = api_token
      @connection = Excon.new(ENV['TIRAMIZOO_API_HOST'], debug: Rails.env.development?)
    end

    def create_order(sender = {}, recipient = {}, packages = [], time_window = {}, options = {})
      sender    = sender.slice("address_line", "postal_code", "country_code", "name", "phone_number", "information")
      recipient = recipient.slice("address_line", "postal_code", "country_code", "name", "phone_number", "information")

      body = {
        "pickup" => sender.merge({
          "after" => time_window["pickup_after"]
        }),
        "delivery" => recipient.merge({
          "after"  => time_window["delivery_after"],
          "before" => time_window["delivery_before"]
        }),
        "packages" => packages.map do |p|
          p.slice("width", "height", "length", "description", "quantity")
        end
      }

      if options["external_id"].present?
        body["external_id"] = options["external_id"]
      end

      if options["web_hook_url"].present?
        body["web_hook_url"] = options["web_hook_url"]
      end

      if options["recipient_email"].present?
        body["recipient_email"] = options["recipient_email"]
      end

      response = connection.post({
        :path    => "/api/v1/orders",
        :headers => {"Api-Token" => api_token,  "Content-Type" => "application/json"},
        :body    => body.to_json
      })

      case response.status
        when 201
          JSON.parse(response.body)
        when 401
          raise InvalidApiToken
        when 422
          raise UnprocessableEntity.new(JSON.parse(response.body))
        when 500
          raise ServerError
        when 503
          raise ServerIsUndergoingMaintenance
        else
          raise UnknownError
      end
    end

    def calculate_distance(origin, destination)
      response = connection.get({
        :path          => "/api/v1/distance",
        :query         => {
          :origin       => origin.values.join(","),
          :destination  => destination.values.join(",")
        },
        :headers       => {"Api-Token" => api_token},
        :idempotent    => true,
        :read_timeout  => 1,
        :write_timeout => 1
      })

      case response.status
        when 200
          JSON.parse(response.body)["distance"]
        when 401
          raise InvalidApiToken
      end
    end

    def geocode(address_line, postal_code, city, country_code)
      response = connection.get({
        :path          => "/api/v1/geocode",
        :query         => {
          :address_line => address_line,
          :postal_code  => postal_code,
          :country_code => country_code,
          :city         => city
        },
        :headers       => {"Api-Token" => api_token},
        :idempotent    => true,
        :read_timeout  => 1,
        :write_timeout => 1
      })

      case response.status
        when 200
          JSON.parse(response.body)
        when 401
          raise InvalidApiToken
      end
    end

  end
end
