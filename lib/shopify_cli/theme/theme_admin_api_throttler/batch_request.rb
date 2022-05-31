# frozen_string_literal: true

module ShopifyCLI
  module Theme
    class ThemeAdminAPIThrottler
      class BatchRequest
        def initialize(method, path, args)
          @method = method
          @path = path
          @args = args
        end

        def size
        end
      end
    end
  end
end
