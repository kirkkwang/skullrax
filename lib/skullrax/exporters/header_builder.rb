# frozen_string_literal: true

module Skullrax
  class HeaderBuilder
    attr_reader :rows, :include_files

    def initialize(rows:, include_files:)
      @rows = rows
      @include_files = include_files
    end

    def build
      fixed_columns + dynamic_columns + visibility_columns + file_columns
    end

    private

    def fixed_columns
      %i[model id]
    end

    def dynamic_columns
      all_keys - fixed_columns - visibility_columns - [:file]
    end

    def visibility_columns
      Skullrax::VisibilityHandler.headers & all_keys
    end

    def file_columns
      include_files ? [:file] : []
    end

    def all_keys
      @all_keys ||= rows.flat_map(&:keys).uniq
    end
  end
end
