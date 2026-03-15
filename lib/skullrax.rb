# frozen_string_literal: true

require 'doorkeeper'
require_relative 'skullrax/version'
require_relative 'skullrax/configuration'
require_relative 'skullrax/engine'

require_relative 'skullrax/concerns/object_not_found'
require_relative 'skullrax/concerns/schema_property_filter_concern'
require_relative 'skullrax/concerns/resource_management_concern'
require_relative 'skullrax/concerns/transaction_concern'
require_relative 'skullrax/concerns/generator_concern'

require_relative 'skullrax/handlers/visibility_handler'
require_relative 'skullrax/handlers/based_near_handler'
require_relative 'skullrax/handlers/controlled_vocabulary_handler'
require_relative 'skullrax/handlers/file_attachment_handler'

require_relative 'skullrax/parameter_builder'
require_relative 'skullrax/file_set_params_builder'
require_relative 'skullrax/work_transaction_executor'

require_relative 'skullrax/valkyrie_collection_generator'
require_relative 'skullrax/valkyrie_work_generator'
require_relative 'skullrax/valkyrie_file_set_generator'

require_relative 'skullrax/importers/resource_fetcher'
require_relative 'skullrax/importers/csv_importer'
require_relative 'skullrax/importers/csv_parser'
require_relative 'skullrax/importers/csv_row'
require_relative 'skullrax/importers/row_processor'
require_relative 'skullrax/importers/resource_processor'
require_relative 'skullrax/importers/file_set_collector'
require_relative 'skullrax/importers/work_row_preparer'
require_relative 'skullrax/importers/uploaded_file_handler'
require_relative 'skullrax/importers/zip_extractor'

require_relative 'skullrax/exporters/csv_exporter'
require_relative 'skullrax/exporters/csv_presenter'
require_relative 'skullrax/exporters/file_handler'
require_relative 'skullrax/exporters/zip_packager'
require_relative 'skullrax/exporters/csv_generator'
require_relative 'skullrax/exporters/header_builder'
require_relative 'skullrax/exporters/row_builder'

require_relative 'skullrax/mcp/tool'
require_relative 'skullrax/mcp/tools/get_schema_tool'
require_relative 'skullrax/mcp/tools/validate_resources_tool'
require_relative 'skullrax/mcp/tools/create_resources_tool'
require_relative 'skullrax/mcp/tools/find_resources_tool'
require_relative 'skullrax/mcp/tools/update_resources_tool'
require_relative 'skullrax/mcp/tools/delete_resources_tool'
require_relative 'skullrax/mcp/tools/reindex_resources_tool'
require_relative 'skullrax/mcp/tools/delete_solr_documents_tool'

module Skullrax
  class Error < StandardError; end
  class InvalidControlledVocabularyTerm < Error; end
  class ObjectNotFoundError < Error; end
  class IdAlreadyExistsError < Error; end
  class ArgumentError < Error; end
  class CsvParsingError < StandardError; end

  def self.config
    @config ||= Configuration.new
  end

  def self.configure
    yield config
  end

  def self.root
    @root ||= Pathname.new(File.expand_path('..', __dir__))
  end
end
