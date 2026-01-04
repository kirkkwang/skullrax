# frozen_string_literal: true

module Skullrax
  class SidebarLinkComponent < ViewComponent::Base
    def initialize(menu:)
      @menu = menu
    end

    def call
      menu.nav_link(skullrax_path, class: 'nav-link', onclick: 'dontChangeAccordion(event);') do
        link_content
      end
    end

    private

    attr_reader :menu

    def skullrax_path
      helpers.skullrax.root_path
    end

    def link_content
      icon = render(icon_component.new(classes: 'mr-3'))
      text = content_tag(:span, 'Skullrax', class: 'sidebar-action-text')
      (icon + text).html_safe
    end

    def icon_component
      Skullrax::Icons::SkullComponent
    end
  end
end
