# frozen_string_literal: true

RSpec.describe 'MCP endpoints' do
  before(:all) do
    Skullrax::Engine.routes.draw do
      post 'mcp', to: 'mcp#handle'
      get  'mcp', to: 'mcp#handle'
      get  '.well-known/oauth-protected-resource',
           to: 'well_known#oauth_protected_resource',
           as: :oauth_protected_resource,
           format: false
    end
  end

  after(:all) do
    Rails.application.reload_routes!
  end

  describe Skullrax::McpController do
    describe 'without authentication' do
      it 'returns 401 Unauthorized' do
        post skullrax.mcp_path, as: :json, params: { jsonrpc: '2.0', method: 'tools/list', id: 1 }

        expect(response).to have_http_status(:unauthorized)
      end

      it 'includes WWW-Authenticate header with MCP realm and resource metadata URL' do
        post skullrax.mcp_path, as: :json, params: { jsonrpc: '2.0', method: 'tools/list', id: 1 }

        expect(response.headers['WWW-Authenticate']).to include('Bearer realm="mcp"')
        expect(response.headers['WWW-Authenticate']).to include('.well-known/oauth-protected-resource')
      end
    end

    describe 'with valid token (stubbed)' do
      let(:user) { create(:user) }

      before do
        allow_any_instance_of(Skullrax::McpController).to receive(:doorkeeper_authorize!)
        allow_any_instance_of(Skullrax::McpController).to receive(:current_resource_owner).and_return(user)
      end

      describe 'initialize method' do
        it 'returns server info' do
          post skullrax.mcp_path, as: :json, params: { jsonrpc: '2.0', method: 'initialize', id: 1 }

          body = JSON.parse(response.body)
          expect(response).to have_http_status(:ok)
          expect(body.dig('result', 'protocolVersion')).to be_present
          expect(body.dig('result', 'serverInfo', 'name')).to eq('Skullrax MCP')
        end
      end

      describe 'tools/list method' do
        it 'returns list of all tool descriptors' do
          post skullrax.mcp_path, as: :json, params: { jsonrpc: '2.0', method: 'tools/list', id: 1 }

          body = JSON.parse(response.body)
          expect(response).to have_http_status(:ok)
          expect(body['result']['tools']).to be_an(Array)
          expect(body['result']['tools'].length).to eq(6)
        end

        it 'includes expected tool names' do
          post skullrax.mcp_path, as: :json, params: { jsonrpc: '2.0', method: 'tools/list', id: 1 }

          body = JSON.parse(response.body)
          tool_names = body['result']['tools'].map { |t| t['name'] }

          expect(tool_names).to include(
            'get_schema',
            'validate_resources',
            'create_resources',
            'find_resources',
            'update_resources',
            'delete_resources'
          )
        end

        it 'each tool descriptor has name, description, and inputSchema' do
          post skullrax.mcp_path, as: :json, params: { jsonrpc: '2.0', method: 'tools/list', id: 1 }

          body = JSON.parse(response.body)
          body['result']['tools'].each do |tool|
            expect(tool['name']).to be_present
            expect(tool['description']).to be_present
            expect(tool['inputSchema']).to be_a(Hash)
          end
        end
      end

      describe 'tools/call method' do
        let(:schema_tool) { instance_double(Skullrax::Mcp::Tools::GetSchemaTool) }

        before do
          allow(Skullrax::Mcp::Tools::GetSchemaTool).to receive(:new).and_return(schema_tool)
          allow(schema_tool).to receive(:call).and_return({
                                                            content: [{ type: 'text', text: '[]' }]
                                                          })
        end

        it 'dispatches to the named tool' do
          post skullrax.mcp_path, as: :json, params: {
            jsonrpc: '2.0',
            method: 'tools/call',
            params: { name: 'get_schema', arguments: { model: 'Monograph' } },
            id: 1
          }

          expect(response).to have_http_status(:ok)
          expect(schema_tool).to have_received(:call)
            .with(params: { 'model' => 'Monograph' }, current_user: user)
        end

        it 'returns JSON-RPC formatted response' do
          post skullrax.mcp_path, as: :json, params: {
            jsonrpc: '2.0',
            method: 'tools/call',
            params: { name: 'get_schema', arguments: { model: 'Monograph' } },
            id: 42
          }

          body = JSON.parse(response.body)
          expect(body['jsonrpc']).to eq('2.0')
          expect(body['id']).to eq(42)
          expect(body['result']).to be_a(Hash)
        end

        it 'returns error for unknown tool name' do
          post skullrax.mcp_path, as: :json, params: {
            jsonrpc: '2.0',
            method: 'tools/call',
            params: { name: 'nonexistent_tool', arguments: {} },
            id: 1
          }

          body = JSON.parse(response.body)
          expect(body['error']).to be_present
          expect(body['error']['code']).to eq(-32_601)
        end
      end

      describe 'unknown method' do
        it 'returns method not found error' do
          post skullrax.mcp_path, as: :json, params: { jsonrpc: '2.0', method: 'unknown/method', id: 1 }

          body = JSON.parse(response.body)
          expect(body['error']['code']).to eq(-32_601)
        end
      end
    end
  end

  describe Skullrax::WellKnownController do
    describe 'GET /.well-known/oauth-protected-resource' do
      it 'returns resource and authorization_servers' do
        get skullrax.oauth_protected_resource_path

        body = JSON.parse(response.body)
        expect(response).to have_http_status(:ok)
        expect(body['resource']).to include('/skullrax/mcp')
        expect(body['authorization_servers']).to be_an(Array)
        expect(body['authorization_servers'].first).not_to include('/skullrax')
      end
    end
  end
end
