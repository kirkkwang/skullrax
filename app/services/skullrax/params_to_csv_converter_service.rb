# frozen_string_literal: true

module Skullrax
  class ParamsToCsvConverterService
    def initialize(params)
      @params = params
      @rows = []
    end

    def to_csv
      sort_hash
      collect_rows
      generate_csv
    end

    private

    attr_reader :params, :rows

    def sort_hash
      sorted_params = params.sort_by do |_key, value|
        value['type'] == 'CollectionResource' ? 1 : 0
      end.to_h
      @params = sorted_params
    end

    def collect_rows
      params.each_value do |resource|
        process_resource(resource)
      end
    end

    def process_resource(resource)
      rows << build_row(resource)

      nested_keys.each do |key|
        next unless resource[key]

        resource[key].each_value do |nested_resource|
          process_resource(nested_resource)
        end
      end
    end

    def build_row(resource)
      row = {}
      file_values = []

      resource.each do |key, value|
        next if nested_keys.include?(key)

        value = conform_model!(value) if key == 'type'
        process_attribute(key, value, row, file_values)
      end

      add_file_column(row, file_values)
      row
    end

    def process_attribute(key, value, row, file_values)
      mapped_key = key_mappings[key] || key

      if files_key_mappings.key?(key)
        collect_file_values(value, file_values)
      else
        row[mapped_key] = format_value(value)
      end
    end

    def collect_file_values(value, file_values)
      conformed = conform_file_paths!(value)
      file_values.concat(Array.wrap(conformed))
    end

    def add_file_column(row, file_values)
      row['file'] = file_values.join(delimiter) if file_values.any?
    end

    def format_value(value)
      Array.wrap(value).join(delimiter)
    end

    def generate_csv
      return '' if rows.empty?

      headers = rows.flat_map(&:keys).uniq

      CSV.generate do |csv|
        csv << headers
        rows.each do |row|
          csv << headers.map { |h| row[h] }
        end
      end
    end

    def conform_model!(model)
      Wings::ModelRegistry.reverse_lookup(model.constantize).to_s.presence || model
    end

    def conform_file_paths!(file_paths)
      Array.wrap(file_paths).map do |path|
        path.respond_to?(:tempfile) ? path.tempfile.path : path
      end
    end

    def key_mappings
      {
        'type' => 'model'
      }.merge(files_key_mappings)
    end

    def files_key_mappings
      {
        'file' => 'file',
        'files' => 'file',
        'remote_file' => 'file',
        'remote_files' => 'file'
      }
    end

    def nested_keys
      %w[works filesets]
    end

    def delimiter
      ';'
    end
  end
end
