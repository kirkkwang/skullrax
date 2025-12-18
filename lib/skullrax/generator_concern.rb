# frozen_string_literal: true

module Skullrax
  module GeneratorConcern
    attr_accessor :errors
    attr_reader :autofill, :except, :kwargs

    delegate :required_properties, :settable_properties, to: :parameter_builder

    def parameter_builder
      @parameter_builder ||= ParameterBuilder.new(model:, autofill:, except:, **kwargs)
    end

    private

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
