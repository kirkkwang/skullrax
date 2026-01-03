# frozen_string_literal: true

module Skullrax
  module Exporters
    class FileHandler
      attr_reader :storage_adapter, :base_path

      def initialize(base_path:)
        @base_path = base_path
        @storage_adapter = Hyrax.storage_adapter
      end

      def download(resource)
        return unless resource.respond_to?(:original_file) && resource.original_file

        file_metadata = resource.original_file
        relative_path = File.join(resource.id.to_s, file_metadata.original_filename)
        full_path = File.join(base_path, relative_path)

        FileUtils.mkdir_p(File.dirname(full_path))
        write_file(file_metadata, full_path)

        relative_path
      end

      private

      def write_file(file_metadata, destination)
        file = storage_adapter.find_by(id: file_metadata.file_identifier)

        File.open(destination, 'wb') do |_f|
          FileUtils.cp(file.disk_path, destination)
        end
      end
    end
  end
end
