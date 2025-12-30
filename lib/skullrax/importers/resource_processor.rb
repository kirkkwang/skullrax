# frozen_string_literal: true

module Skullrax
  class ResourceProcessor
    def initialize(action:, errors:, merge: false, autofill: false, except: [])
      @action = action
      @errors = errors
      @merge = merge
      @autofill = autofill
      @except = except
    end

    def process(row)
      instantiate_generator(row).tap do |generator|
        perform_action(generator)
        capture_errors(generator, row.number) if generator.errors.present?
      end
    end

    private

    attr_reader :action, :errors, :merge, :autofill, :except

    def instantiate_generator(row)
      row.generator_class.new(**row)
    end

    def perform_action(generator)
      case action
      when :create  then generator.generate(autofill:, except:)
      when :update  then generator.update(merge:, autofill:, except:)
      when :destroy then generator.destroy
      end
    end

    def capture_errors(generator, row_number)
      errors << {
        row_number:,
        resource_type: generator.resource.class,
        errors: generator.errors
      }
    end
  end
end
