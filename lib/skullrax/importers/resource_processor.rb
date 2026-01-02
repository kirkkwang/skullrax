# frozen_string_literal: true

module Skullrax
  class ResourceProcessor
    def initialize(action:, errors:, dry_run: false, merge: false, autofill: false, except: [], fill_required: false) # rubocop:disable Metrics/ParameterLists
      @action = action
      @errors = errors
      @dry_run = dry_run
      @merge = merge
      @autofill = autofill
      @except = except
      @fill_required = fill_required
    end

    def process(row)
      instantiate_generator(row).tap do |generator|
        perform_action(generator)
        capture_errors(generator, row.number) if generator.errors.present?
      end
    end

    private

    attr_reader :action, :errors, :dry_run, :merge, :autofill, :except, :fill_required

    def instantiate_generator(row)
      row.generator_class.new(**row)
    end

    def perform_action(generator)
      case action
      when :create  then generator.generate(autofill:, except:, dry_run:, fill_required:)
      when :update  then generator.update(merge:, autofill:, except:, dry_run:)
      when :destroy then generator.destroy(dry_run:)
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
