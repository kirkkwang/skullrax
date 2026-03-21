# frozen_string_literal: true

module Skullrax
  class McpController < ActionController::API
    include Doorkeeper::Rails::Helpers
    include Doorkeeper::Helpers::Controller

    before_action :doorkeeper_authorize!

    TOOLS = [
      Skullrax::Mcp::Tools::GetSchemaTool,
      Skullrax::Mcp::Tools::ValidateResourcesTool,
      Skullrax::Mcp::Tools::CreateResourcesTool,
      Skullrax::Mcp::Tools::FindResourcesTool,
      Skullrax::Mcp::Tools::UpdateResourcesTool,
      Skullrax::Mcp::Tools::DeleteResourcesTool,
      Skullrax::Mcp::Tools::ReindexResourcesTool,
      Skullrax::Mcp::Tools::DeleteSolrDocumentsTool,
      Skullrax::Mcp::Tools::FindMembersTool,
      Skullrax::Mcp::Tools::ManageDerivativesTool
    ].freeze

    def handle
      case params[:method]
      when 'initialize'
        render_initialize
      when 'tools/list'
        render_tools_list
      when 'tools/call'
        render_tool_call
      else
        render_method_not_found
      end
    end

    private

    # Override current_resource_owner to look up the user directly from the
    # doorkeeper_token instead of going through resource_owner_authenticator
    # (which calls warden.authenticate! and triggers a Devise redirect when
    # there is no session cookie, bypassing rescue StandardError).
    def current_resource_owner
      return nil unless doorkeeper_token

      ::User.find_by(id: doorkeeper_token.resource_owner_id)
    end

    # Override Doorkeeper's unauthorized response to include the MCP-required
    # WWW-Authenticate header pointing to the OAuth protected resource metadata URL.
    def doorkeeper_unauthorized_render_options(*)
      response.headers['WWW-Authenticate'] =
        %(Bearer realm="mcp", resource_metadata="#{request.base_url}/.well-known/oauth-protected-resource")
      { json: { error: 'Unauthorized' }, status: :unauthorized }
    end

    def render_initialize
      render json: {
        jsonrpc: '2.0',
        id: params[:id],
        result: {
          protocolVersion: '2024-11-05',
          capabilities: { tools: {} },
          serverInfo: { name: 'Skullrax MCP', version: Skullrax::VERSION }
        }
      }
    end

    def render_tools_list
      render json: {
        jsonrpc: '2.0',
        id: params[:id],
        result: { tools: TOOLS.map(&:descriptor) }
      }
    end

    def render_tool_call # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      tool_name = params.dig(:params, :name)
      arguments = params.dig(:params, :arguments)&.to_unsafe_h || {}

      tool_class = TOOLS.find { |t| t.tool_name == tool_name }

      unless tool_class
        render json: {
          jsonrpc: '2.0',
          id: params[:id],
          error: { code: -32_601, message: "Tool not found: #{tool_name}" }
        }
        return
      end

      result = tool_class.new.call(params: arguments, current_user: current_resource_owner)

      render json: {
        jsonrpc: '2.0',
        id: params[:id],
        result:
      }
    rescue StandardError => e
      render json: {
        jsonrpc: '2.0',
        id: params[:id],
        error: { code: -32_000, message: e.message }
      }
    end

    def render_method_not_found
      render json: {
        jsonrpc: '2.0',
        id: params[:id],
        error: { code: -32_601, message: "Method not found: #{params[:method]}" }
      }
    end
  end
end
