# frozen_string_literal: true

require_relative "errors"

module ShopifyCLI
  module Theme
    class ThemeAdminAPIThrottler
      class ResponseParser
        def initialize(response_body)
          @response_body = response_body
        end

        def parse
        end

        private

        def assets
          @response_body.map do |response_bodies|
            body = JSON.parse(response_bodies[:body])
            body["asset"]
          end
        end

        def fetch(key)
          values = @response_body.map { |response_bodies| response_bodies[key] }.uniq

          return values.first if values.one?

          error_message = "requests with multiple values for '#{key}' cannot be parsed"
          raise Errors::RequestParserError, error_message
        end
      end
    end
  end
end
