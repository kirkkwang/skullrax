# frozen_string_literal: true

module Skullrax
  class PageComponent < ViewComponent::Base
    def header_content
      tag.h1 do
        render(icon_component.new(classes:, color:)) + header_text
      end
    end

    private

    def classes
      'mr-1'
    end

    def color
      '#6E757C'
    end

    def header_text
      " #{t('skullrax.dashboard.header')}"
    end

    def icon_component
      Skullrax::Icons::SkullComponent
    end
  end
end
