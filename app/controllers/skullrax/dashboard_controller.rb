# frozen_string_literal: true

module Skullrax
  class DashboardController < Skullrax::ApplicationController
    def index
      render Skullrax::PageComponent.new
    end
  end
end
