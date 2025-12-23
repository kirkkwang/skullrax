# frozen_string_literal: true

module Skullrax
  class CsvParser
    HEADER_MAPPINGS = {
      'file' => 'file_paths'
    }.freeze

    def initialize(importer:)
      @csv = importer.csv
      @delimiter = importer.delimiter
    end

    def parse
      parsed_csv_rows.map { |row| process_row(row) }
    end

    private

    attr_reader :csv, :delimiter

    def parsed_csv_rows
      CSV.parse(csv, headers: true, header_converters: ->(header) { HEADER_MAPPINGS.fetch(header, header) })
    end

    def process_row(row)
      symbolized_hash(row).tap { |hash| constantize_model!(hash) }
    end

    def symbolized_hash(row)
      row.to_h.compact.transform_keys(&:to_sym).each_with_object({}) do |(key, value), hash|
        hash[key] = should_split_value?(key, value) ? split_value(value) : value
      end
    end

    def should_split_value?(key, value)
      value.is_a?(String) && properties_to_split.include?(key)
    end

    def properties_to_split
      @properties_to_split ||= unique_models.flat_map { |model| splittable_properties(model) }.uniq
    end

    def unique_models
      @unique_models ||= parsed_csv_rows.map { |row| row['model'] }.uniq.compact.map(&:constantize)
    end

    def splittable_properties(model)
      model.schema.filter_map { |schema_key| schema_key.name if schema_key.meta['form'].present? }
    end

    def split_value(value)
      value.split(delimiter).map(&:strip)
    end

    def constantize_model!(hash)
      return unless hash[:model]

      hash[:model] = model_constant(hash[:model])
    end

    def model_constant(model_string)
      model_string.safe_constantize.tap { |model| validate_model!(model) }
    end

    def validate_model!(model)
      raise Skullrax::ArgumentError, 'Invalid model class in CSV' if model.nil?
    end
  end
end
