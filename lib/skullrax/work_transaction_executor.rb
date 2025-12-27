# frozen_string_literal: true

class WorkTransactionExecutor
  attr_reader :action, :params, :user, :form, :file_set_params_builder

  def initialize(action:, params:, user:, form:, file_set_params_builder:)
    @action = action
    @params = params
    @user = user
    @form = form
    @file_set_params_builder = file_set_params_builder
  end

  def create
    action.transactions[action.transaction_name]
          .with_step_args(**create_step_args)
          .call(action.form)
  end

  def update
    action.transactions['change_set.update_work']
          .with_step_args(**update_step_args)
          .call(form)
  end

  private

  def create_step_args
    {
      'work_resource.add_to_parent' => { parent_id: params[:parent_id], user: },
      'work_resource.add_file_sets' => { uploaded_files:, file_set_params: transformed_file_set_params },
      'change_set.set_user_as_depositor' => { user: },
      'work_resource.change_depositor' => { user: ::User.find_by_user_key(form.on_behalf_of) },
      'work_resource.save_acl' => { permissions_params: form.input_params['permissions'] }
    }
  end

  def update_step_args
    {
      'work_resource.add_file_sets' => { uploaded_files:, file_set_params: transformed_file_set_params },
      'work_resource.update_work_members' => { work_members_attributes: {} },
      'work_resource.save_acl' => { permissions_params: form.input_params['permissions'] }
    }
  end

  def uploaded_files
    return [] if file_set_params_builder.uploaded_file_ids.blank?

    Hyrax::UploadedFile.where(id: file_set_params_builder.uploaded_file_ids)
  end

  def transformed_file_set_params
    file_set_params_builder.formatted_file_set_params.map do |parameters|
      parameters.permit!.to_h.symbolize_keys
    end
  end
end
