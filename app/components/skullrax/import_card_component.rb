# frozen_string_literal: true

module Skullrax
  class ImportCardComponent < ViewComponent::Base
    def import_path
      helpers.skullrax.imports_path
    end
  end
end
