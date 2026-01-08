# frozen_string_literal: true

module Skullrax
  class CsvParser
    include SchemaPropertyFilterConcern

    attr_reader :found_resources

    def initialize(csv:, delimiter:, action:, found_resources: [])
      @csv = csv
      @delimiter = delimiter
      @action = action
      self.found_resources = found_resources
    end

    def found_resources=(resources)
      @found_resources = resources
      @found_resources_by_id = resources.index_by { |r| r.id.to_s }
    end

    def parse
      parsed_csv_table.map.with_index { |row, i| process_row(row, i) }
    end

    def validate_ids_present!
      missing_count = parsed_csv_table.count { |r| r[:id].blank? }
      return if missing_count.zero?

      raise Skullrax::ArgumentError,
            "Update and destroy requires ID column for all rows. #{missing_count} rows missing IDs."
    end

    def raw_ids
      Array(parsed_csv_table[:id]).compact
    end

    def parsed_csv_table
      @parsed_csv_table ||=
        CSV.parse(csv, headers: true, header_converters: [->(h) { header_mappings.fetch(h, h) }, :symbol])
    rescue CSV::MalformedCSVError => e
      raise Skullrax::CsvParsingError, "Malformed CSV: #{e.message}"
    end

    private

    attr_reader :csv, :delimiter, :action, :found_resources_by_id

    def header_mappings
      {
        'file' => 'file_paths'
      }
    end

    def process_row(row, index)
      hash = row.to_h
      inject_existing_model!(hash)
      normalize_hash!(hash)
      Skullrax::CsvRow.new(hash:, index:)
    end

    def inject_existing_model!(hash)
      id = hash[:id]
      return unless id && (resource = found_resources_by_id[id])

      hash[:model] = resource.class.to_s
    end

    def normalize_hash!(hash)
      hash[:model] = normalize_and_constantize(hash[:model])
      hash.compact!
      split_delimited_values!(hash)
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
      @unique_models ||= parsed_csv_table.filter_map { |row| row[:model] }
                                         .uniq
                                         .map { |m| normalize_and_constantize(m) }
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
