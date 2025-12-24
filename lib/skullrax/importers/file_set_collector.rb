# frozen_string_literal: true

module Skullrax
  class FileSetCollector
    def initialize(rows, indices_to_skip)
      @rows = rows
      @indices_to_skip = indices_to_skip
    end

    def collect_after(current_index)
      starting_index = next_index(current_index)
      consecutive_file_sets(starting_index).tap { |rows| mark_indices(starting_index, rows) }
    end

    private

    attr_reader :rows, :indices_to_skip

    def next_index(current_index)
      current_index + 1
    end

    def consecutive_file_sets(starting_index)
      rows[starting_index..].take_while { |row| row[:model]&.file_set? }
    end

    def mark_indices(starting_index, file_set_rows)
      file_set_rows.each_index { |offset| indices_to_skip.add(starting_index + offset) }
    end
  end
end
