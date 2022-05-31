# frozen_string_literal: true

require_relative "errors"

module ShopifyCLI
  module Theme
    class ThemeAdminAPIThrottler
      class RequestParser
        def initialize(list_of_params)
          @list_of_params = list_of_params
        end

        def parse
          {
            shop: fetch(:shop),
            path: fetch(:path),
            method: fetch(:method),
            api_version: "unstable",
            body: JSON.generate({ assets: assets }),
          }
        end

        private

        def assets
          @list_of_params.map do |params|
            body = JSON.parse(params[:body])
            body["asset"]
          end
        end

        def fetch(key)
          values = @list_of_params.map { |params| params[key] }.uniq

          return values.first if values.one?

          error_message = "requests with multiple values for '#{key}' cannot be parsed"
          raise Errors::RequestParserError, error_message
        end
      end
    end
  end
end
