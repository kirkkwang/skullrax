# frozen_string_literal: true

module Skullrax
  # rubocop:disable Metrics/ClassLength
  class ParamsToCsvConverterService
    def initialize(params:, batch_uploads_dir: nil)
      @params = params
      @rows = []
      @batch_uploads_dir = batch_uploads_dir || Rails.root.join('tmp', 'skullrax_batch_uploads', SecureRandom.hex(8))
    end

    def to_csv
      sort_hash
      collect_rows
      generate_csv
    end

    private

    attr_reader :params, :rows, :batch_uploads_dir

    def sort_hash
      sorted_params = params.sort_by do |_key, value|
        model = value['model'] || value['type']
        model == 'CollectionResource' ? 1 : 0
      end.to_h

      @params = sorted_params
    end

    def collect_rows
      params.each_value { |resource| process_resource(resource) }
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
        next if nested_keys.include?(key) || Array.wrap(value).compact_blank.empty?

        value = conform_model!(value) if %w[type model].include?(key)
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
      values = Array.wrap(value)
      return values.to_json if values.any?(Hash)

      values.join(delimiter)
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
      return model unless defined?(Wings)

      Wings::ModelRegistry.reverse_lookup(model.constantize).to_s.presence || model
    end

    def conform_file_paths!(file_paths)
      Array.wrap(file_paths).map do |path|
        if path.respond_to?(:tempfile) && path.respond_to?(:original_filename)
          dest = @batch_uploads_dir.join(path.original_filename)
          FileUtils.mkdir_p(dest.dirname)
          FileUtils.mv(path.tempfile.path, dest)
          dest.to_s
        else
          path
        end
      end
    end

    def key_mappings
      {
        'type' => 'model',
        'model' => 'model'
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

    def nested_keys = %w[works filesets]

    def delimiter = ';'
  end
  # rubocop:enable Metrics/ClassLength
end
