# frozen_string_literal: true

require "forwardable"

require_relative "theme_admin_api_throttler/batch"
require_relative "theme_admin_api_throttler/batch_request"
require_relative "theme_admin_api_throttler/errors"

module ShopifyCLI
  module Theme
    class ThemeAdminAPIThrottler
      extend Forwardable

      def_delegators :@admin_api, :get, :post, :delete, :rest_request

      def initialize(ctx, admin_api)
        @ctx = ctx
        @admin_api = admin_api
        @active = false
      end

      def put(path:, **args, &block)
        if active?
          batch_request(method: "PUT", path: bulk_path(path), **args, &block)
        else
          rest_request(method: "PUT", path: path, **args, &block)
        end

      rescue Errors::TimeoutError
        @ctx.debug("throttling timeout: #{path} => #{args}")

        # performs the regular request as a fallback
        rest_request(method: "PUT", path: path, **args)
      end

      def activate!
        @active = true
      end

      def deactivate!
        @active = false
      end

      def active?
        @active
      end

      private

      def batch_request(method:, path:, **args, &block)
        request = BatchRequest.new(method, path, args)

        batch.enqueue(request)
        return unless batch.ready?(request)

        block.call(batch.request)
      end

      def batch
        @batch ||= Batch.new(@admin_api)
      end

      def bulk_path(path)
        path.gsub(/.json$/, "/bulk.json")
      end
    end
  end
end
