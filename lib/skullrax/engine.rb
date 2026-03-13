# frozen_string_literal: true

module Skullrax
  class Engine < ::Rails::Engine
    isolate_namespace Skullrax

    ActiveSupport::Reloader.to_prepare do
      Hyrax::DashboardController.sidebar_partials[:repository_content] << 'hyrax/dashboard/sidebar/skullrax'
    end

    initializer 'skullrax.assets.precompile' do |app|
      app.config.assets.precompile += %w[skullrax.js skullrax.css]
    end

    initializer 'skullrax.oauth_discovery', after: :add_routing_paths do |app|
      next unless Skullrax.config.mcp_enabled?

      app.routes.append do
        get '/.well-known/oauth-authorization-server',
            to: 'skullrax/well_known#oauth_authorization_server',
            format: false
        get '/.well-known/oauth-protected-resource',
            to: 'skullrax/well_known#oauth_protected_resource',
            format: false
        post '/register',
             to: 'skullrax/well_known#register',
             format: false
      end
    end

    initializer 'skullrax.doorkeeper' do
      ::Doorkeeper.configure do
        orm :active_record
        resource_owner_authenticator do
          current_user || warden.authenticate!(scope: :user)
        end
        admin_authenticator do
          current_user&.admin? || redirect_to(main_app.new_user_session_path)
        end
        optional_scopes :mcp, :openid, :email, :profile
      end
    end
  end
end
