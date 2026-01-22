# frozen_string_literal: true

module Skullrax
  class ExportCardComponent < ViewComponent::Base
    def export_path
      helpers.skullrax.exports_path.split('?').first
    end
  end
end
