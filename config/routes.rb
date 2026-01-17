# frozen_string_literal: true

Skullrax::Engine.routes.draw do
  root to: 'dashboard#index'

  resources :imports, only: [:create]
  post 'batch_create', to: 'batch_create#create'
  get 'exports', to: 'exports#create'
end
