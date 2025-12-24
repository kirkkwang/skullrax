# frozen_string_literal: true

require_relative 'skullrax/version'

require_relative 'skullrax/concerns/object_not_found'
require_relative 'skullrax/concerns/schema_property_filter_concern'
require_relative 'skullrax/concerns/generator_concern'

require_relative 'skullrax/handlers/visibility_handler'
require_relative 'skullrax/handlers/based_near_handler'
require_relative 'skullrax/handlers/controlled_vocabulary_handler'
require_relative 'skullrax/handlers/file_attachment_handler'

require_relative 'skullrax/error_formatter'
require_relative 'skullrax/parameter_builder'
require_relative 'skullrax/file_set_params_builder'
require_relative 'skullrax/work_transaction_executor'

require_relative 'skullrax/generators/valkyrie_work_generator'
require_relative 'skullrax/generators/valkyrie_collection_generator'

require_relative 'skullrax/importers/csv_importer'
require_relative 'skullrax/importers/csv_parser'
require_relative 'skullrax/importers/row_processor'
require_relative 'skullrax/importers/file_set_collector'
require_relative 'skullrax/importers/work_row_preparer'

module Skullrax
  class Error < StandardError; end
  class InvalidControlledVocabularyTerm < Error; end
  class CollectionNotFoundError < Error; end
  class WorkNotFoundError < Error; end
  class IdAlreadyExistsError < Error; end
  class ArgumentError < Error; end

  def self.root
    @root ||= Pathname.new(File.expand_path('..', __dir__))
  end
end
