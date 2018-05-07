require 'tiramizoo/version'
require 'logger'
require 'excon'

module Tiramizoo
  class Api
    class InvalidApiToken               < StandardError; end
    class ServerError                   < StandardError; end
    class NotFound                      < StandardError; end
    class UnprocessableEntity           < StandardError; end
    class ServerIsUndergoingMaintenance < StandardError; end
    class UnknownError                  < StandardError; end

    attr_reader :connection, :api_token

    def initialize(api_token)
      @api_token  = api_token
      @connection = Excon.new(ENV['TIRAMIZOO_API_HOST'], debug: Rails.env.development?)
    end

    def logger
      @logger ||= Logger.new(STDOUT)
    end

    def configuration
      response = connection.get({
        :path    => "/api/v1/configuration",
        :headers => {"Api-Token" => api_token,  "Content-Type" => "application/json"}
      })

      case response.status
        when 200
          JSON.parse(response.body)
        when 401
          raise InvalidApiToken
        when 500
          raise ServerError
        when 503
          raise ServerIsUndergoingMaintenance
        else
          logger.warn("[tiramizoo-api] status: #{response.status}, body: #{response.body}")
          raise UnknownError.new(response.status_line)
      end
    end

    def service_areas
      response = connection.get({
        :path    => "/api/v1/service_areas",
        :headers => {"Api-Token" => api_token,  "Content-Type" => "application/json"}
      })

      case response.status
        when 200
          JSON.parse(response.body)
        when 401
          raise InvalidApiToken
        when 500
          raise ServerError
        when 503
          raise ServerIsUndergoingMaintenance
        else
          logger.warn("[tiramizoo-api] status: #{response.status}, body: #{response.body}")
          raise UnknownError.new(response.status_line)
      end
    end

    def create_order(sender = {}, recipient = {}, packages = [], time_window = {}, options = {})
      body = {
        "pickup"   => sender,
        "delivery" => recipient,
        "packages" => packages.map do |p|
          p.slice("width", "height", "length", "weight", "description", "quantity", "category", "external_id", "non_rotatable")
        end
      }

      body["delivery_type"]      = options["delivery_type"].presence
      body["pickup"]["after"]    = time_window["pickup_after"].presence
      body["pickup"]["before"]   = time_window["pickup_before"].presence
      body["delivery"]["after"]  = time_window["delivery_after"].presence
      body["delivery"]["before"] = time_window["delivery_before"].presence

      body["external_id"]     = options["external_id"].presence
      body["web_hook_url"]    = options["web_hook_url"].presence
      body["recipient_email"] = options["recipient_email"].presence
      body["description"]     = options["description"].presence

      # premium time window
      body["premium_pickup"]   = {}
      body["premium_delivery"] = {}
      body["premium_pickup"]["after"]    = options["premium_pickup_after"].presence
      body["premium_pickup"]["before"]   = options["premium_pickup_before"].presence
      body["premium_delivery"]["before"] = options["premium_delivery_before"].presence

      body["pickup"].compact!
      body["delivery"].compact!
      body["premium_pickup"].compact!
      body["premium_delivery"].compact!
      body.compact!

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
          raise UnprocessableEntity.new(response.body.force_encoding("utf-8"))
        when 500
          raise ServerError
        when 503
          raise ServerIsUndergoingMaintenance
        else
          logger.warn("[tiramizoo-api] status: #{response.status}, body: #{response.body}")
          raise UnknownError.new(response.status_line)
      end
    end

    def cancel_order(order_identifier)
      body = {
        "state"               => "cancelled",
        "cancellation_reason" => "user"
      }

      response = connection.put({
        :path    => "/api/v1/orders/#{order_identifier}",
        :headers => {"Api-Token" => api_token,  "Content-Type" => "application/json"},
        :body    => body.to_json
      })

      case response.status
        when 200
          JSON.parse(response.body)
        when 401
          raise InvalidApiToken
        when 404
          raise NotFound
        when 422
          raise UnprocessableEntity.new(response.body.force_encoding("utf-8"))
        when 500
          raise ServerError
        when 503
          raise ServerIsUndergoingMaintenance
        else
          logger.warn("[tiramizoo-api] status: #{response.status}, body: #{response.body}")
          raise UnknownError.new(response.status_line)
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
        else
          logger.warn("[tiramizoo-api] status: #{response.status}, body: #{response.body}")
          raise UnknownError.new(response.status_line)
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
        else
          logger.warn("[tiramizoo-api] status: #{response.status}, body: #{response.body}")
          raise UnknownError.new(response.status_line)
      end
    end

  end
end
