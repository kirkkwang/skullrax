# frozen_string_literal: true

require_relative 'skullrax/version'
require_relative 'skullrax/generator_concern'
require_relative 'skullrax/controlled_vocabulary_handler'
require_relative 'skullrax/error_formatter'
require_relative 'skullrax/valkyrie_work_generator'
require_relative 'skullrax/file_uploader'
require_relative 'skullrax/parameter_builder'
require_relative 'skullrax/based_near_handler'
require_relative 'skullrax/file_set_params_builder'
require_relative 'skullrax/transaction_executor'
require_relative 'skullrax/visibility_handler'
require_relative 'skullrax/valkyrie_collection_generator'

module Skullrax
  class Error < StandardError; end

  def self.root
    @root ||= Pathname.new(File.expand_path('..', __dir__))
  end
end
