# frozen_string_literal: true

module Skullrax
  class CsvRow < DelegateClass(Hash)
    attr_reader :index, :number
    attr_accessor :generator_class

    delegate :collection?, :work?, :file_set?, to: :model

    def initialize(hash:, index: nil)
      super(hash)
      define_dynamic_methods
      @index = index
      @number = index + 2 if index.present?
      @generator_class = find_generator_class
    end

    def find_generator_class
      if collection?
        ValkyrieCollectionGenerator
      elsif work?
        ValkyrieWorkGenerator
      elsif file_set?
        ValkyrieFileSetGenerator
      end
    end

    def merge(other_hash, &block)
      new_hash = super(other_hash, &block)
      self.class.new(hash: new_hash, index:)
    end

    private

    def define_dynamic_methods
      relevant_keys.each do |key|
        next if respond_to?(key)

        define_singleton_method(key) { self[key] }
      end
    end

    def relevant_keys
      keys | [:id]
    end
  end
end
