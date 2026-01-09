# frozen_string_literal: true

module Skullrax
  class ResourceProcessor
    # rubocop:disable Metrics/ParameterLists
    def initialize(
      action:, errors:, dry_run: false, merge: false, autofill: false, except: [], fill_required: false,
      files_path: nil, user: nil
    )
      @action = action
      @errors = errors
      @dry_run = dry_run
      @merge = merge
      @autofill = autofill
      @except = except
      @fill_required = fill_required
      @files_path = files_path
      @user = user
      @validated_file_paths = Set.new
    end
    # rubocop:enable Metrics/ParameterLists

    def mark_as_validated(file_path)
      @validated_file_paths.add(file_path)
    end

    def clear_validated_paths
      @validated_file_paths.clear
    end

    def process(row)
      instantiate_generator(row).tap do |generator|
        perform_action(generator)
        capture_errors(generator, row.number) if generator.errors.present?
      end
    end

    private

    attr_reader :action, :errors, :dry_run, :merge, :autofill, :except, :fill_required, :files_path, :user,
                :validated_file_paths

    def instantiate_generator(row)
      attributes = row.to_h

      if files_path.present? && attributes[:file_paths].present?
        attributes[:file_paths] = resolve_file_paths(Array.wrap(attributes[:file_paths]))
      end

      row.generator_class.new(
        **attributes,
        user:,
        validated_file_paths:
      )
    end

    def resolve_file_paths(filenames)
      filenames.map do |filename|
        File.join(files_path, filename)
      end
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
