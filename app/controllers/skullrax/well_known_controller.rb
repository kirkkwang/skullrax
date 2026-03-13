# frozen_string_literal: true

module Skullrax
  class WellKnownController < ActionController::API
    def oauth_protected_resource
      # script_name is the engine mount prefix (e.g. "/skullrax") when reached via the engine
      # route, but may be empty when reached via the root-level route added by the initializer.
      # Always resolve the MCP resource URL via the engine's named route to be mount-agnostic.
      mcp_resource_url = Skullrax::Engine.routes.url_helpers.mcp_url(host: request.host_with_port,
                                                                     protocol: request.protocol.delete_suffix('://'))
      render json: {
        resource: mcp_resource_url,
        authorization_servers: [request.base_url]
      }
    end

    def oauth_authorization_server
      base = request.base_url
      render json: {
        issuer: base,
        authorization_endpoint: "#{base}/oauth/authorize",
        token_endpoint: "#{base}/oauth/token",
        registration_endpoint: "#{base}/register",
        response_types_supported: ['code'],
        grant_types_supported: ['authorization_code'],
        code_challenge_methods_supported: ['S256']
      }
    end

    def register # rubocop:disable Metrics/MethodLength
      redirect_uris = Array(params[:redirect_uris])
      app = Doorkeeper::Application.create!(
        name: params[:client_name].presence || 'MCP Client',
        redirect_uri: redirect_uris.join("\n"),
        scopes: '',
        confidential: false
      )
      render json: {
        client_id: app.uid,
        client_name: app.name,
        redirect_uris: app.redirect_uri.split,
        grant_types: ['authorization_code'],
        token_endpoint_auth_method: 'none'
      }, status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: 'invalid_client_metadata', error_description: e.message }, status: :bad_request
    end
  end
end
