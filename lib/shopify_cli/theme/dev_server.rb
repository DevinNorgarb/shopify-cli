# frozen_string_literal: true
require_relative "development_theme"
require_relative "ignore_filter"
require_relative "syncer"

require_relative "dev_server/cdn_fonts"
require_relative "dev_server/hot_reload"
require_relative "dev_server/header_hash"
require_relative "dev_server/reload_mode"
require_relative "dev_server/local_assets"
require_relative "dev_server/proxy"
require_relative "dev_server/sse"
require_relative "dev_server/watcher"
require_relative "dev_server/remote_watcher"
require_relative "dev_server/web_server"
require_relative "dev_server/certificate_manager"

require "pathname"

module ShopifyCLI
  module Theme
    module DevServer
      # Errors
      Error = Class.new(StandardError)
      AddressBindingError = Class.new(Error)

      class << self
        attr_accessor :ctx

        def start(ctx, root, host: "127.0.0.1", theme: nil, port: 9292, poll: false, editor_sync: false,
          mode: ReloadMode.default)
          @ctx = ctx
          theme = find_theme(root, theme)
          ignore_filter = IgnoreFilter.from_path(root)
          @syncer = Syncer.new(ctx, theme: theme, ignore_filter: ignore_filter, overwrite_json: !editor_sync)
          watcher = Watcher.new(ctx, theme: theme, ignore_filter: ignore_filter, syncer: @syncer, poll: poll)
          remote_watcher = RemoteWatcher.to(theme: theme, syncer: @syncer)

          # Setup the middleware stack. Mimics Rack::Builder / config.ru, but in reverse order
          @app = Proxy.new(ctx, theme: theme, syncer: @syncer)
          @app = CdnFonts.new(@app, theme: theme)
          @app = LocalAssets.new(ctx, @app, theme: theme)
          @app = HotReload.new(ctx, @app, theme: theme, watcher: watcher, mode: mode, ignore_filter: ignore_filter)
          stopped = false
          address = "http://#{host}:#{port}"

          trap("INT") do
            stopped = true
            stop
          end

          CLI::UI::Frame.open(@ctx.message("theme.serve.viewing_theme")) do
            ctx.print_task(ctx.message("theme.serve.syncing_theme", theme.id, theme.shop))
            @syncer.start_threads
            if block_given?
              yield @syncer
            else
              @syncer.upload_theme!(delay_low_priority_files: true)
            end

            return if stopped

            preview_suffix = editor_sync ? "" : ctx.message("theme.serve.download_changes")
            preview_message = ctx.message(
              "theme.serve.customize_or_preview",
              preview_suffix,
              theme.editor_url,
              theme.preview_url
            )

            ctx.puts(ctx.message("theme.serve.serving", theme.root))
            ctx.open_url!(address)
            ctx.puts(preview_message)
          end

          logger = if ctx.debug?
            WEBrick::Log.new(nil, WEBrick::BasicLog::INFO)
          else
            WEBrick::Log.new(nil, WEBrick::BasicLog::FATAL)
          end

          watcher.start
          remote_watcher.start if editor_sync
          WebServer.run(
            @app,
            BindAddress: host,
            Port: port,
            Logger: logger,
            AccessLog: [],
          )
          remote_watcher.stop if editor_sync
          watcher.stop

        rescue ShopifyCLI::API::APIRequestForbiddenError,
               ShopifyCLI::API::APIRequestUnauthorizedError
          shop = ShopifyCLI::AdminAPI.get_shop_or_abort(@ctx)
          raise ShopifyCLI::Abort, @ctx.message("theme.serve.ensure_user", shop)
        rescue Errno::EADDRINUSE
          error_message = @ctx.message("theme.serve.address_already_in_use", address)
          help_message = @ctx.message("theme.serve.try_port_option")
          @ctx.abort(error_message, help_message)
        rescue Errno::EADDRNOTAVAIL
          raise AddressBindingError, "Error binding to the address #{host}."
        end

        def stop
          @ctx.puts("Stopping…")
          @app.close
          @syncer.shutdown
          WebServer.shutdown
        end

        private

        def find_theme(root, identifier)
          return theme_by_identifier(root, identifier) if identifier
          DevelopmentTheme.find_or_create!(@ctx, root: root)
        end

        def theme_by_identifier(root, identifier)
          theme = ShopifyCLI::Theme::Theme.find_by_identifier(@ctx, root: root, identifier: identifier)
          theme || not_found_error(identifier)
        end

        def not_found_error(identifier)
          @ctx.abort(@ctx.message("theme.serve.theme_not_found", identifier))
        end
      end
    end
  end
end
