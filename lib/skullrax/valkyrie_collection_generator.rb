# frozen_string_literal: true

module Skullrax
  class ValkyrieCollectionGenerator
    attr_accessor :collection

    include Skullrax::GeneratorConcern

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

    private

    def model
      Hyrax.config.collection_class
    end

    def params
      { attributes_key => params_hash }
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

    def assign_resource(resource)
      self.collection = resource
    end
  end
end
