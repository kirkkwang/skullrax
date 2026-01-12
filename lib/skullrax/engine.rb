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
  end
end
