# frozen_string_literal: true

module Skullrax
  class ValkyrieCollectionGenerator
    include Skullrax::GeneratorConcern

    def initialize(**kwargs)
      @resource = nil
      @kwargs = kwargs
      @id = kwargs.delete(:id)
      @errors = []
    end

    def resource
      @resource ||= model.new(collection_type_gid:).tap do |c|
        c.id = id if id.present?
      end
    end

    private

    def perform_create_action
      form.validate(params)

      result =
        transactions['change_set.create_collection']
        .with_step_args(**create_step_args)
        .call(form)

      result.success? ? handle_success(result) : handle_failure(result)
    end

    def perform_update_action
      form.validate(merged_kwargs)

      result = transactions['change_set.update_collection']
               .with_step_args(**update_step_args)
               .call(form)

      result.success? ? handle_success(result) : handle_failure(result)
    end

    def form
      @form ||= Hyrax::Forms::ResourceForm.for(resource:).tap(&:prepopulate!)
    end

    def params
      { attributes_key => params_hash }
    end

    def create_step_args
      {
        'change_set.set_user_as_depositor' => { user: },
        'change_set.add_to_collections' => { collection_ids: Array(params[:parent_id]) },
        'collection_resource.apply_collection_type_permissions' => { user: }
      }
    end

    def update_step_args
      {
        'collection_resource.save_collection_banner' => {
          update_banner_file_ids: [], banner_unchanged_indicator: true
        },
        'collection_resource.save_collection_logo' => {
          update_logo_file_ids: [], alttext_values: [], linkurl_values: [], logo_unchanged_indicator: false
        }
      }
    end

    def model
      Hyrax.config.collection_class
    end

    def collection_type_gid
      Hyrax::CollectionType.find(default_collection_type.id).to_global_id
    end

    def default_collection_type
      Hyrax::CollectionType.find_or_create_default_collection_type
    end
  end
end
