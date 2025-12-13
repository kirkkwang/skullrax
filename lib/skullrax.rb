# frozen_string_literal: true

require_relative 'skullrax/version'
require_relative 'skullrax/controlled_vocabulary_handler'
require_relative 'skullrax/error_formatter'
require_relative 'skullrax/valkyrie_work_generator'
require_relative 'skullrax/file_uploader'
require_relative 'skullrax/parameter_builder'

module Skullrax
  class Error < StandardError; end

  def self.root
    @root ||= Pathname.new(File.expand_path('..', __dir__))
  end
end
