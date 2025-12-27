# frozen_string_literal: true

module Skullrax
  module GeneratorConcern
    attr_accessor :errors, :autofill, :except, :fill_mode
    attr_reader :id, :kwargs, :merge, :merged_kwargs
    attr_writer :resource

    delegate :required_properties, :settable_properties, to: :parameter_builder

    include Skullrax::ObjectNotFound

    def generate(autofill: false, fill_required: true, except: [])
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

    def create
      @fill_mode = :none
      @except = []
      execute_creation
    end

    def update(merge: false, autofill: false, except: [])
      @merge = merge
      @fill_mode = autofill ? :all : :none
      @except = Array.wrap(except).map(&:to_s)
      execute_update
    end

    def parameter_builder
      ParameterBuilder.new(model:, fill_mode:, except:, **kwargs)
    end

    private

    def execute_creation
      check_id
      @merged_kwargs = params_hash
      validate_form
      perform_create_action
    end

    def execute_update
      retrieve_existing_resource
      merge_attributes
      validate_form
      perform_update_action
    end

    def check_id
      return unless id.present?

      begin
        Hyrax.query_service.find_by(id:)
        raise Skullrax::IdAlreadyExistsError, "ID '#{id}' is already in use. Update not yet implemented."
      rescue *object_not_found_errors
        true
      end
    end

    def retrieve_existing_resource
      raise Skullrax::ArgumentError, 'ID required for updates' unless id.present?

      existing_resource = Hyrax.query_service.find_by(id:)
      assign_resource(existing_resource)
    rescue *object_not_found_errors
      raise Skullrax::ObjectNotFoundError, "No resource found with ID '#{id}' to update."
    end

    def merge_attributes
      existing_attrs = resource.attributes

      @merged_kwargs = existing_attrs.merge(params_hash) do |_, old_val, new_val|
        should_append?(old_val) ? old_val + new_val : new_val
      end
    end

    def should_append?(value)
      merge && value.is_a?(Array)
    end

    def assign_resource(resource)
      self.resource = resource
    end

    def validate_form
      form.validate(merged_kwargs || params[attributes_key])
    end

    def handle_success(result)
      assign_resource(result.value!)
      result
    end

    def handle_failure(result)
      formatter = ErrorFormatter.new(result)
      formatter.log
      @errors << formatter.format
      result
    end

    def params_hash
      @params_hash ||= parameter_builder.build
    end

    def attributes_key
      model.model_name.param_key
    end

    def user
      @user ||= User.find_by_email('admin@example.com')
    end

    def transactions
      Hyrax::Transactions::Container
    end
  end
end
