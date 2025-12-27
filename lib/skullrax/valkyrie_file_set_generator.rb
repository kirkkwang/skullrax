# frozen_string_literal: true

module Skullrax
  class ValkyrieFileSetGenerator
    attr_reader :id, :kwargs

    include Skullrax::GeneratorConcern

    def initialize(id:, **kwargs)
      @resource = nil
      @kwargs = kwargs
      @id = id
      @errors = []
    end

    def resource
      @resource ||= Hyrax.query_service.find_by(id:)
    end

    private

    def perform_update_action
      form.validate(merged_kwargs)

      result =
        transactions['change_set.update_file_set']
        .with_step_args('file_set.save_acl' => { permissions_params: form.input_params['permissions'] })
        .call(form)

      result.success? ? handle_success(result) : handle_failure(result)
    end

    def model
      Hyrax.config.file_set_class
    end
  end
end
