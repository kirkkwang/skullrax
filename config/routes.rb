# frozen_string_literal: true

Skullrax::Engine.routes.draw do
  root to: 'dashboard#index'

  resources :imports, only: [:create]
end
