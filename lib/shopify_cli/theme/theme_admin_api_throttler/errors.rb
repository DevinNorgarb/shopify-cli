# frozen_string_literal: true

module ShopifyCLI
  module Theme
    class ThemeAdminAPIThrottler
      module Errors
        class TimeoutError < RuntimeError; end
        class RequestParserError < RuntimeError; end
      end
    end
  end
end
