# frozen_string_literal: true

module Skullrax
  class YmlToCsvConverterService
    def initialize(yml_path:)
      @yml_path = yml_path
    end

    def to_csv
      params = transform_to_params(yml_data['resources'])
      Skullrax::ParamsToCsvConverterService.new(params:).to_csv
    end

    private

    def yml_data
      @yml_data ||= YAML.load_file(@yml_path)
    end

    def transform_to_params(resources)
      {}.tap do |params|
        resources.each_with_index do |resource, index|
          params["resource-#{index}"] = transform_resource(resource)
        end
      end
    end

    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    def transform_resource(resource)
      {}.tap do |transformed|
        resource.each do |key, value|
          case key
          when 'works'
            transformed['works'] = transform_nested(value, :work)
          when 'filesets'
            transformed['filesets'] = transform_nested(value, :fileset)
          when 'file', 'files', 'remote_file', 'remote_files'
            transformed[key] = resolve_paths(value)
          when 'thumbnail', 'banner', 'logo'
            transformed[key] = resolve_path(Array.wrap(value).first.to_s) if value.present?
          else
            transformed[key] = value
          end
        end
      end
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

    def transform_nested(resources, type)
      {}.tap do |nested|
        resources.each_with_index do |resource, index|
          nested["#{type}-#{index}"] = transform_resource(resource)
        end
      end
    end

    def resolve_paths(value)
      Array.wrap(value).map { |v| resolve_path(v) }
    end

    def resolve_path(path)
      return path if path.start_with?('http') || path.start_with?('/')

      Rails.root.join(path).to_s
    end
  end
end
