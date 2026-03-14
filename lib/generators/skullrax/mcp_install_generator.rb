# frozen_string_literal: true

module Skullrax
  # Opt-in installer for the Skullrax MCP server feature.
  #
  # Sets config.mcp_enabled = true in the Skullrax initializer (which activates
  # the MCP routes already defined in the engine) and sets up Doorkeeper OAuth tables.
  #
  # Run after skullrax:install:
  #   rails generate skullrax:mcp_install
  class McpInstallGenerator < Rails::Generators::Base
    source_root File.expand_path('templates', __dir__)

    def enable_mcp
      if mcp_already_enabled?
        skip_message('MCP already enabled in Skullrax initializer')
      elsif initializer_exists?
        gsub_file initializer_path, /# (config\.mcp_enabled = true)/, '\1'
        success_message('MCP enabled in config/initializers/skullrax.rb')
      else
        create_file initializer_path, minimal_initializer
        success_message('Created config/initializers/skullrax.rb with MCP enabled')
      end
    end

    def install_doorkeeper
      if doorkeeper_migration_exists?
        skip_message('Doorkeeper migration already exists')
      else
        generate 'doorkeeper:install'
        generate 'doorkeeper:migration'
        success_message('Doorkeeper installed — run `rails db:migrate` to create OAuth tables')
      end
    end

    def inject_use_doorkeeper
      routes_path = File.join(destination_root, 'config/routes.rb')
      return skip_message('use_doorkeeper already in routes') if File.read(routes_path).include?('use_doorkeeper')

      inject_into_file routes_path, "  use_doorkeeper\n", after: /Rails\.application\.routes\.draw do[^\n]*\n/
      success_message('Injected use_doorkeeper into config/routes.rb')
    end

    def configure_doorkeeper_initializer # rubocop:disable Metrics/MethodLength
      doorkeeper_init = File.join(destination_root, 'config/initializers/doorkeeper.rb')
      unless File.exist?(doorkeeper_init)
        return skip_message('config/initializers/doorkeeper.rb not found — skipping patch')
      end

      content = File.read(doorkeeper_init)

      if content.include?('current_user || warden.authenticate!')
        return skip_message('Doorkeeper initializer already configured for Skullrax')
      end

      # Replace the boilerplate resource_owner_authenticator with working Devise integration
      gsub_file doorkeeper_init,
                /resource_owner_authenticator do\n\s+raise[^\n]+\n\s+end/,
                "resource_owner_authenticator do\n    current_user || warden.authenticate!(scope: :user)\n  end"

      # Append admin_authenticator before the closing end
      unless content.include?('admin_authenticator')
        admin_block = "  admin_authenticator do\n    current_user&.admin? || " \
                      "redirect_to(main_app.new_user_session_path)\n  end\n\n"
        inject_into_file doorkeeper_init, admin_block, before: /^end$/
      end

      # Append optional_scopes for MCP before the closing end
      unless content.include?('optional_scopes')
        inject_into_file doorkeeper_init,
                         "  optional_scopes :mcp, :openid, :email, :profile\n",
                         before: /^end$/
      end

      success_message('Patched config/initializers/doorkeeper.rb with Skullrax MCP configuration')
    end

    private

    def initializer_exists?
      File.exist?(initializer_path)
    end

    def mcp_already_enabled?
      initializer_exists? && File.read(initializer_path).match?(/^\s*config\.mcp_enabled = true/)
    end

    def doorkeeper_migration_exists?
      Dir.glob(File.join(destination_root, 'db/migrate/*_create_doorkeeper_tables.rb')).any?
    end

    def initializer_path
      File.join(destination_root, 'config/initializers/skullrax.rb')
    end

    def minimal_initializer
      <<~RUBY
        # frozen_string_literal: true

        Skullrax.configure do |config|
          config.mcp_enabled = true
        end
      RUBY
    end

    def skip_message(message)
      say_status('skipped', message, :yellow)
    end

    def success_message(message)
      say_status('success', message, :green)
    end
  end
end
