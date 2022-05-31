# frozen_string_literal: true

require_relative "errors"

module ShopifyCLI
  module Theme
    class ThemeAdminAPIThrottler
      class Batch
        def initialize(admin_api)
          @admin_api = admin_api
          @thread_pool = ShopifyCLI::ThreadPool.new
        end

        def enqueue(request)
          @thread_pool.schedule(request)
        end

        def wait_request(request)
          retries = 10

          while request.done?
            retries -= 1
            wait
          end

          raise Errors::TimeoutError unless request.done?
        end

        def shutdown
          @thread_pool.shutdown
        end

        private

        def wait
          sleep(0.1)
        end
      end
    end
  end
end
