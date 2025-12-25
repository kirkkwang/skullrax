# frozen_string_literal: true

module Skullrax
  module CreatorConcern
    attr_accessor :errors
    attr_reader :autofill, :except, :id, :kwargs
    attr_writer :resource

    delegate :required_properties, :settable_properties, to: :parameter_builder

    include Skullrax::ObjectNotFound

    def parameter_builder
      @parameter_builder ||= ParameterBuilder.new(model:, autofill:, except:, **kwargs)
    end

    def create
      check_id
      validate_form
      perform_action
    end

    private

    def check_id
      return unless id.present?

      begin
        Hyrax.query_service.find_by(id:)
        raise Skullrax::IdAlreadyExistsError, "ID '#{id}' is already in use. Update not yet implemented."
      rescue *object_not_found_errors
        true
      end
    end

    def assign_resource(resource)
      self.resource = resource
    end

    def validate_form
      form.validate(params[attributes_key])
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
