# frozen_string_literal: true

module Skullrax
  class ValkyrieCollectionGenerator
    attr_accessor :collection
    attr_reader :errors, :autofill, :except, :kwargs

    delegate :required_properties, :settable_properties, to: :parameter_builder

    def initialize(autofill: false, except: [], **kwargs)
      @autofill = autofill
      @except = Array.wrap(except).map(&:to_s)
      @collection = model.new(collection_type_gid:)
      @kwargs = kwargs
      @errors = []
    end

    def create
      validate_form
      perform_action
    end

    def parameter_builder
      @parameter_builder ||= ParameterBuilder.new(model:, autofill:, except:, **kwargs)
    end

    private

    def model
      Hyrax.config.collection_class
    end

    def user
      @user ||= User.find_by_email('admin@example.com')
    end

    def validate_form
      form.validate(params[collection_attributes_key])
    end

    def collection_attributes_key
      model.model_name.param_key
    end

    def params
      { collection_attributes_key => params_hash }
    end

    def params_hash
      @params_hash ||= parameter_builder.build
    end

    def transactions
      Hyrax::Transactions::Container
    end

    def form
      @form ||= Hyrax::Forms::ResourceForm.for(resource: collection).tap(&:prepopulate!)
    end

    def collection_type_gid
      Hyrax::CollectionType.find(default_collection_type.id).to_global_id
    end

    def default_collection_type
      Hyrax::CollectionType.find_or_create_default_collection_type
    end

    def perform_action
      form.validate(params)

      result =
        transactions['change_set.create_collection']
        .with_step_args(
          'change_set.set_user_as_depositor' => { user: },
          'change_set.add_to_collections' => { collection_ids: Array(params[:parent_id]) },
          'collection_resource.apply_collection_type_permissions' => { user: }
        )
        .call(form)
      result.success? ? handle_success(result) : handle_failure(result)
    end

    def handle_success(result)
      self.collection = result.value!
      result
    end

    def handle_failure(result)
      formatter = ErrorFormatter.new(result)
      formatter.log
      @errors << formatter.format
      result
    end
  end
end
