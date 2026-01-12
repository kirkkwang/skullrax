# frozen_string_literal: true

module Skullrax
  class InstallGenerator < Rails::Generators::Base
    source_root File.expand_path('templates', __dir__)

    def mount_skullrax_route
      return skip_message('Skullrax route already mounted') if already_mounted?

      inject_into_file route_file_path, after: route_draw_line do
        skullrax_route
      end

      success_message('Skullrax route mounted at /skullrax')
    end

    def add_asset_precompile
      return skip_message('Skullrax assets already added to precompile list') if assets_already_added?
      return skip_message('assets.rb not found, skipping asset precompile config') unless File.exist?(assets_file_path)

      append_to_file assets_file_path, skullrax_precompile_line

      success_message('Added Skullrax assets to precompile list')
    end

    private

    def already_mounted?
      File.read(route_file_path).include?('mount Skullrax::Engine')
    end

    def assets_already_added?
      return false unless File.exist?(assets_file_path)

      File.read(assets_file_path).include?('skullrax/*')
    end

    def skip_message(message)
      say_status('skipped', message, :yellow)
    end

    def success_message(message)
      say_status('success', message, :green)
    end

    def skullrax_route
      "  mount Skullrax::Engine => '/skullrax'\n"
    end

    def route_file
      'config/routes.rb'
    end

    def route_file_path
      File.join(destination_root, route_file)
    end

    def route_draw_line
      /Rails\.application\.routes\.draw do.*\n/
    end

    def assets_initializer
      'config/initializers/assets.rb'
    end

    def assets_file_path
      File.join(destination_root, assets_initializer)
    end

    def skullrax_precompile_line
      "Rails.application.config.assets.precompile += %w(skullrax/*)\n"
    end
  end
end
