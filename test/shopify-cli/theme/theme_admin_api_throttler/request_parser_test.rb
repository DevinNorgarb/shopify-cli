# frozen_string_literal: true

require "test_helper"
require "shopify_cli/theme/theme"
require "shopify_cli/theme/theme_admin_api_throttler/errors"
require "shopify_cli/theme/theme_admin_api_throttler/request_parser"

module ShopifyCLI
  module Theme
    class ThemeAdminAPIThrottler
      class RequestParserTest < Minitest::Test
        def setup
          super

          ShopifyCLI::DB
            .stubs(:exists?)
            .with(:shop)
            .returns(true)
          ShopifyCLI::DB
            .stubs(:get)
            .with(:shop)
            .returns("shop.myshopify.com")
        end

        def test_fetch
          expected_shop = "shop.myshopify.com"

          parser = RequestParser.new([
            { shop: expected_shop },
            { shop: expected_shop },
          ])

          actual_shop = parser.send(:fetch, :shop)

          assert_equal(expected_shop, actual_shop)
        end

        def test_fetch_when_params_are_not_valid
          parser = RequestParser.new([
            { shop: "shop1.myshopify.com" },
            { shop: "shop2.myshopify.com" },
          ])

          error = assert_raises(Errors::RequestParserError) do
            parser.send(:fetch, :shop)
          end

          actual_error_message = error.message
          expected_error_message = "requests with multiple values for 'shop' cannot be parsed"

          assert_equal(expected_error_message, actual_error_message)
        end

        def test_parse
          parser = RequestParser.new([
            {
              shop: theme.shop,
              path: "themes/#{theme.id}/assets.json",
              method: "PUT",
              api_version: "unstable",
              body: JSON.generate({
                asset: {
                  key: "assets/theme.css",
                  value: theme["assets/theme.css"].read,
                },
              }),
            },
            {
              shop: theme.shop,
              path: "themes/#{theme.id}/assets.json",
              method: "PUT",
              api_version: "unstable",
              body: JSON.generate({
                asset: {
                  key: "assets/logo.png",
                  attachment: Base64.encode64(theme["assets/logo.png"].read),
                },
              }),
            },
          ])

          actual_request = parser.parse
          expected_request = {
            shop: "shop.myshopify.com",
            path: "themes/123/assets.json",
            method: "PUT",
            api_version: "unstable",
            body: JSON.generate({
              assets: [
                {
                  key: "assets/theme.css",
                  value: theme["assets/theme.css"].read,
                },
                {
                  key: "assets/logo.png",
                  attachment: Base64.encode64(theme["assets/logo.png"].read),
                },
              ],
            }),
          }

          assert_equal(expected_request, actual_request)
        end

        private

        def theme
          @theme ||= Theme.new(ctx, root: root, id: "123")
        end

        def ctx
          @ctx ||= TestHelpers::FakeContext.new(root: root)
        end

        def root
          ShopifyCLI::ROOT + "/test/fixtures/theme"
        end
      end
    end
  end
end
