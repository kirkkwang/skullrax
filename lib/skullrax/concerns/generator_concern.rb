# frozen_string_literal: true

module Skullrax
  module GeneratorConcern # rubocop:disable Metrics/ModuleLength
    include ResourceManagementConcern
    include TransactionConcern
    include Skullrax::ObjectNotFound
    include Dry::Monads[:result]

    attr_accessor :errors, :autofill, :except, :fill_mode, :resource
    attr_reader :id, :kwargs, :merge, :merged_kwargs, :dry_run, :validated_file_paths

    delegate :required_properties, :settable_properties, to: :parameter_builder

    def generate(autofill: false, fill_required: true, except: [], dry_run: false)
      @dry_run = dry_run
      @fill_mode = if autofill
                     :all
                   elsif fill_required
                     :required
                   else
                     :none
                   end
      @except = Array.wrap(except).map(&:to_s)
      execute_creation
    end

    def create(dry_run: false)
      @dry_run = dry_run
      @fill_mode = :none
      @except = []
      execute_creation
    end

    def update(merge: false, autofill: false, except: [], dry_run: false)
      @dry_run = dry_run
      @merge = merge
      @fill_mode = autofill ? :all : :none
      @except = Array.wrap(except).map(&:to_s)
      execute_update
    end

    def destroy(dry_run: false)
      @dry_run = dry_run
      execute_destroy
    end

    def parameter_builder
      ParameterBuilder.new(model:, fill_mode:, except:, **kwargs)
    end

    private

    def execute_creation
      check_id
      @merged_kwargs = params_hash
      return validation_failure unless valid_for_execution?

      form.sync
      return dry_run_success if dry_run?

      perform_create_action
    end

    def execute_update
      retrieve_existing_resource
      merge_attributes
      return validation_failure unless valid_for_execution?

      form.sync
      return dry_run_success if dry_run?

      perform_update_action
    end

    def execute_destroy
      retrieve_existing_resource
      return dry_run_success if dry_run?

      perform_destroy_action
    end

    def valid_for_execution?
      if validate_form
        true
      else
        @errors ||= []
        @errors.concat(form.errors.full_messages)
        false
      end
    end

    def validation_failure = Failure(@errors)

    def dry_run_success = Success(resource)

    def dry_run? = !!@dry_run

    def merge_attributes
      existing_attrs = deserialized_resource_attributes
      new_attrs = params_hash.transform_keys(&:to_sym)
      merge_compound_attributes!(existing_attrs, new_attrs) if merge

      @merged_kwargs = existing_attrs.merge(new_attrs) do |_, old_val, new_val|
        should_append?(old_val) ? old_val + new_val : new_val
      end
    end

    def merge_compound_attributes!(existing_attrs, new_attrs) # rubocop:disable Metrics/AbcSize
      new_attrs.each_key do |key|
        bare = key.to_s.delete_suffix('_attributes').to_sym
        next if bare == key.to_sym || !Skullrax::CompoundHandler.handles?(model, bare)

        old_rows = Array(existing_attrs[bare]).map { |row| row.to_h.stringify_keys }
        next if old_rows.empty?

        combined = old_rows + new_attrs[key].values
        new_attrs[key] = combined.each_with_index.to_h { |row, index| [index.to_s, row] }
      end
    end

    def deserialized_resource_attributes
      attrs = resource.attributes.dup
      return attrs unless resource.respond_to?(:already_ordered_attributes)

      resource.already_ordered_attributes.each_with_object(attrs) do |attr, hash|
        hash[attr] = resource.public_send(attr) if resource.respond_to?(attr)
      end
    end

    def should_append?(value)
      merge && value.is_a?(Array)
    end

    def form
      @form ||= Hyrax::Forms::ResourceForm.for(resource:).tap(&:prepopulate!)
    end

    def validate_form
      form.validate(merged_kwargs || params[attributes_key])
    end

    def validate_attachments(paths)
      return true if paths.blank?

      paths_to_validate = Array.wrap(paths).reject { |path| @validated_file_paths&.include?(path) }
      return true if paths_to_validate.empty?

      handler_errors = Skullrax::FileAttachmentHandler.new(file_paths: paths_to_validate, user:).validate
      return true if handler_errors.empty?

      @errors ||= []
      @errors.concat(handler_errors)
      false
    end

    def params_hash
      @params_hash ||= parameter_builder.build
    end

    def attributes_key = model.model_name.param_key
  end
end
