# frozen_string_literal: true

Skullrax::Engine.routes.draw do
  root to: 'dashboard#index'

  resources :imports, only: [:create]
  post 'batch_create', to: 'batch_create#create'
  get 'exports', to: 'exports#create'

  if Skullrax.config.mcp_enabled?
    post 'mcp', to: 'mcp#handle'
    get  'mcp', to: 'mcp#handle'
    get  '.well-known/oauth-protected-resource',
         to: 'well_known#oauth_protected_resource',
         as: :oauth_protected_resource,
         format: false
  end
end
