# frozen_string_literal: true

module Skullrax
  module Icons
    class SkullComponent < ViewComponent::Base
      attr_reader :classes, :color

      def initialize(classes: '', color: 'currentColor')
        @classes = classes
        @color = color
      end

      def call
        tag.svg(xmlns: 'http://www.w3.org/2000/svg',
                viewBox: '0 0 512 512',
                "aria-hidden": 'true',
                class: classes,
                style: "width: 1em; height: 1em; fill: #{color}; vertical-align: -0.125em;") do
          tag.path(d: 'M416 427.4c58.5-44 96-111.6 96-187.4 0-132.5-114.6-240-256-240S0 107.5 0 240c0 75.8 37.5 143.4 96 187.4L96 464c0 26.5 21.5 48 48 48l32 0 0-40c0-13.3 10.7-24 24-24s24 10.7 24 24l0 40 64 0 0-40c0-13.3 10.7-24 24-24s24 10.7 24 24l0 40 32 0c26.5 0 48-21.5 48-48l0-36.6zM96 256a64 64 0 1 1 128 0 64 64 0 1 1 -128 0zm256-64a64 64 0 1 1 0 128 64 64 0 1 1 0-128z') # rubocop:disable Layout/LineLength
        end
      end
    end
  end
end
