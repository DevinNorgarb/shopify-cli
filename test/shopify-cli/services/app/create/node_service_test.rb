require "test_helper"
require "semantic/semantic"
require "project_types/node/test_helper"

module ShopifyCLI
  module Services
    module App
      module Create
        class NodeServiceTest < MiniTest::Test
          include TestHelpers::Partners
          include TestHelpers::FakeUI
          include TestHelpers::Shopifolk

          ENV_FILE = <<~CONTENT
            SHOPIFY_API_KEY=newapikey
            SHOPIFY_API_SECRET=secret
            SHOP=testshop.myshopify.com
            SCOPES=write_products,write_customers,write_draft_orders
          CONTENT

          SHOPIFYCLI_FILE = <<~APPTYPE
            ---
            project_type: node
            organization_id: 42
            is_new_template: true
          APPTYPE

          def setup
            super
            ShopifyCLI::Tasks::EnsureAuthenticated.stubs(:call)
          end

          def test_check_node_installed
            Environment.expects(:node_version).with(context: @context).raises(ShopifyCLI::Abort)
            assert_raises ShopifyCLI::Abort, "core.errors.missing_node" do
              call_service
            end
          end

          def test_check_npm_installed
            Environment.expects(:npm_version).with(context: @context).raises(ShopifyCLI::Abort)
            assert_raises ShopifyCLI::Abort, "core.errors.missing_npm" do
              call_service
            end
          end

          def test_check_default_npm_registry_is_production
            create_test_app_directory_structure

            expect_node_npm_check_commands
            @context.expects(:capture2).with("npm config get @shopify:registry").returns([
              "https://registry.yarnpkg.com", nil
            ])
            expect_git_clone_commands

            ShopifyCLI::Tasks::CreateApiClient.stubs(:call).returns({
              "apiKey" => "ljdlkajfaljf",
              "apiSecretKeys" => [{ "secret": "kldjakljjkj" }],
              "id" => "12345678",
            })
            ShopifyCLI::Resources::EnvFile.stubs(:new).returns(stub(write: true))

            call_service
            @context.chdir("..")

            refute File.exist?("test-app/.npmrc")
            FileUtils.rm_r("test-app")
          end

          def test_check_default_npm_registry_is_not_production
            create_test_app_directory_structure

            expect_node_npm_check_commands
            @context.expects(:capture2).with("npm config get @shopify:registry")
              .returns(["https://badregistry.com", nil])
            @context.expects(:system).with(
              "npm",
              "--userconfig",
              "./.npmrc",
              "config",
              "set",
              "@shopify:registry",
              "https://registry.yarnpkg.com",
              chdir: @context.root + "/test-app"
            )
            expect_git_clone_commands

            ShopifyCLI::Tasks::CreateApiClient.stubs(:call).returns({
              "apiKey" => "ljdlkajfaljf",
              "apiSecretKeys" => [{ "secret": "kldjakljjkj" }],
              "id" => "12345678",
            })
            ShopifyCLI::Resources::EnvFile.stubs(:new).returns(stub(write: true))

            call_service
            @context.chdir("..")

            FileUtils.rm_r("test-app")
          end

          def test_can_create_new_app
            create_test_app_directory_structure

            @context.stubs(:uname).returns("Mac")
            expect_node_npm_check_commands
            @context.expects(:capture2).with("npm config get @shopify:registry").returns([
              "https://registry.yarnpkg.com", nil
            ])
            expect_git_clone_commands

            stub_partner_req(
              "create_app",
              variables: {
                org: 42,
                title: "test-app",
                type: "public",
                app_url: ShopifyCLI::Tasks::CreateApiClient::DEFAULT_APP_URL,
                redir: ["http://127.0.0.1:3456"],
              },
              resp: {
                'data': {
                  'appCreate': {
                    'app': {
                      'apiKey': "newapikey",
                      'apiSecretKeys': [{ 'secret': "secret" }],
                    },
                  },
                },
              }
            )

            call_service
            @context.chdir("..")

            assert_equal SHOPIFYCLI_FILE, File.read("test-app/.shopify-cli.yml")
            assert_equal ENV_FILE, File.read("test-app/.env")
            refute File.exist?("test-app/.npmrc")
            refute File.exist?("test-app/.git")
            refute File.exist?("test-app/.github")
            refute File.exist?("test-app/.gitmodules")
            refute File.exist?("test-app/package.json.cli2")
            assert File.exist?("test-app/package.json")
            assert File.exist?("test-app/package.json.cli3beta")

            FileUtils.rm_r("test-app")
          end

          def test_can_create_new_app_registry_not_found
            create_test_app_directory_structure

            @context.stubs(:uname).returns("Mac")
            expect_node_npm_check_commands
            expect_git_clone_commands
            @context.expects(:capture2).with("npm config get @shopify:registry")
              .returns(["https://badregistry.com", nil])
            @context.expects(:system).with(
              "npm",
              "--userconfig",
              "./.npmrc",
              "config",
              "set",
              "@shopify:registry",
              "https://registry.yarnpkg.com",
              chdir: @context.root + "/test-app"
            )

            stub_partner_req(
              "create_app",
              variables: {
                org: 42,
                title: "test-app",
                type: "public",
                app_url: ShopifyCLI::Tasks::CreateApiClient::DEFAULT_APP_URL,
                redir: ["http://127.0.0.1:3456"],
              },
              resp: {
                'data': {
                  'appCreate': {
                    'app': {
                      'apiKey': "newapikey",
                      'apiSecretKeys': [{ 'secret': "secret" }],
                    },
                  },
                },
              }
            )

            call_service
            @context.chdir("..")

            assert_equal SHOPIFYCLI_FILE, File.read("test-app/.shopify-cli.yml")
            assert_equal ENV_FILE, File.read("test-app/.env")
            refute File.exist?("test-app/.git")
            refute File.exist?("test-app/.github")
            refute File.exist?("test-app/.gitmodules")
            refute File.exist?("test-app/package.json.cli2")
            assert File.exist?("test-app/package.json")
            assert File.exist?("test-app/package.json.cli3beta")

            FileUtils.rm_r("test-app")
          end

          private

          def call_service
            NodeService.call(
              context: @context,
              name: "test-app",
              type: "public",
              organization_id: "42",
              store_domain: "testshop.myshopify.com",
              verbose: false
            )
          end

          def expect_node_npm_check_commands
            Environment.expects(:node_version).with(context: @context).returns("8.0.0")
            Environment.expects(:npm_version).with(context: @context).returns("1")
          end

          def create_test_app_directory_structure
            FileUtils.mkdir_p("test-app")
            FileUtils.mkdir_p("test-app/web")
            FileUtils.touch("test-app/web/package.json")
            FileUtils.touch("test-app/package.json")
            FileUtils.touch("test-app/package.json.cli2")
            FileUtils.touch("test-app/.git")
            FileUtils.touch("test-app/.github")
            FileUtils.touch("test-app/.gitmodules")
          end

          def expect_git_clone_commands
            ShopifyCLI::Git.expects(:clone).with("https://github.com/Shopify/starter-node-app.git", "test-app")
            ShopifyCLI::Git.expects(:update_submodules).with(@context)
            ShopifyCLI::JsDeps.expects(:install).with(@context, false)
            ShopifyCLI::JsDeps.expects(:install).with(@context, false)
          end
        end
      end
    end
  end
end
