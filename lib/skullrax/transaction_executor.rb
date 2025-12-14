# frozen_string_literal: true

class TransactionExecutor
  def initialize(action:, params:, user:, form:, file_set_params_builder:)
    @action = action
    @params = params
    @user = user
    @form = form
    @file_set_params_builder = file_set_params_builder
  end

  def execute
    @action.transactions[@action.transaction_name]
           .with_step_args(**step_args)
           .call(@action.form)
  end

  private

  def step_args
    {
      'work_resource.add_to_parent' => { parent_id: @params[:parent_id], user: @user },
      'work_resource.add_file_sets' => { uploaded_files:, file_set_params: transformed_file_set_params },
      'change_set.set_user_as_depositor' => { user: @user },
      'work_resource.change_depositor' => { user: ::User.find_by_user_key(@form.on_behalf_of) },
      'work_resource.save_acl' => { permissions_params: @form.input_params['permissions'] }
    }
  end

  def uploaded_files
    Hyrax::UploadedFile.where(id: @params[:uploaded_files])
  end

  def transformed_file_set_params
    @file_set_params_builder.formatted_file_set_params.map do |params|
      params.permit!.to_h.symbolize_keys
    end
  end
end
