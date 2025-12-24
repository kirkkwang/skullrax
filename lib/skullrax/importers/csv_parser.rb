# frozen_string_literal: true

module Skullrax
  class CsvParser
    include SchemaPropertyFilterConcern

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
      CSV.parse(csv, headers: true, header_converters: ->(header) { header_mappings.fetch(header, header) })
    end

    def header_mappings
      {
        'file' => 'file_paths'
      }
    end

    def process_row(row)
      symbolized_hash(row).tap { |hash| split_delimited_values!(hash) }
    end

    def symbolized_hash(row)
      hash = row.to_h.compact.transform_keys(&:to_sym)
      hash[:model] = normalize_and_constantize(hash[:model])
      hash
    end

    def split_delimited_values!(hash)
      hash.each do |key, value|
        next unless should_split_value?(key, value)

        hash[key] = split_value(value)
      end
    end

    def should_split_value?(key, value)
      value.is_a?(String) && properties_to_split.include?(key)
    end

    def properties_to_split
      @properties_to_split ||= unique_models.flat_map { |model| splittable_properties(model) }.uniq
    end

    def unique_models
      @unique_models ||= parsed_csv_rows.filter_map { |row| row['model'] }
                                        .uniq
                                        .map { |model_string| normalize_and_constantize(model_string) }
    end

    def split_value(value)
      value.split(delimiter).map(&:strip)
    end

    def normalize_and_constantize(model_string)
      normalized = model_mappings.fetch(model_string, model_string).constantize
      model = Wings::ModelRegistry.reverse_lookup(normalized) || normalized
      model.tap { |m| validate_model!(m) }
    end

    def model_mappings
      {
        'Collection' => Hyrax.config.collection_class.to_s,
        'FileSet' => Hyrax.config.file_set_class.to_s,
        nil => Skullrax::ValkyrieWorkGenerator.default_model.to_s
      }
    end

    def validate_model!(model)
      raise Skullrax::ArgumentError, 'Invalid model class in CSV' if model.nil?
    end
  end
end
