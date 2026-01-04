# frozen_string_literal: true

module Skullrax
  class ApplicationController < ::ApplicationController
    with_themed_layout 'dashboard'

    include Hyrax::Breadcrumbs
    before_action :build_breadcrumbs

    before_action :authenticate_user!
    before_action :ensure_admin!

    private

    def ensure_admin!
      raise CanCan::AccessDenied, 'You must be an admin to access Skullrax.' unless current_ability.admin?
    rescue CanCan::AccessDenied
      redirect_to main_app.root_path, alert: 'You are not authorized to access Skullrax.'
    end

    def build_breadcrumbs
      add_breadcrumb t(:'hyrax.controls.home'), main_app.root_path
      add_breadcrumb t(:'hyrax.dashboard.title'), hyrax.dashboard_path
      add_breadcrumb 'Skullrax', skullrax.root_path
    end
  end
end
