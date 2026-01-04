# frozen_string_literal: true

module Skullrax
  class InstallGenerator < Rails::Generators::Base
    source_root File.expand_path('templates', __dir__)

    def mount_skullrax_route
      return skip_message if already_mounted?

      inject_into_file route_file_path, after: route_draw_line do
        skullrax_route
      end

      success_message
    end

    private

    def already_mounted?
      File.read(route_file_path).include?('mount Skullrax::Engine')
    end

    def skip_message
      say_status('skipped', 'Skullrax route already mounted', :yellow)
    end

    def success_message
      say_status('success', 'Skullrax route mounted at /skullrax', :green)
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
  end
end
