# frozen_string_literal: true

module Skullrax
  class ValkyrieWorkGenerator
    attr_writer :work
    attr_accessor :errors
    attr_reader :model, :autofill, :except, :kwargs

    delegate :required_properties, :settable_properties, to: :parameter_builder

    def initialize(model: nil, file_paths: [], autofill: false, except: [], **kwargs)
      @model = model || default_model
      @file_paths = Array.wrap(file_paths)
      @autofill = autofill
      @except = Array.wrap(except).map(&:to_s)
      @kwargs = kwargs
      @work = nil
      @errors = []
    end

    def create
      validate_form
      perform_action
    end

    def work
      @work ||= model.new.tap do |w|
        w.depositor = user.email
        w.admin_set_id = admin_set_id
      end
    end

    def parameter_builder
      @parameter_builder ||= ParameterBuilder.new(
        model:,
        autofill:,
        except:,
        **kwargs
      )
    end

    private

    def default_model
      Wings::ModelRegistry.reverse_lookup(Hyrax.config.curation_concerns.first)
    end

    def user
      @user ||= User.find_by_email('admin@example.com')
    end

    def admin_set_id
      @admin_set_id ||= Hyrax::AdminSetCreateService.find_or_create_default_admin_set.id.to_s
    end

    def form
      @form ||= form_class.new(resource: work)
    end

    def form_class
      Hyrax::WorkFormService.form_class(work)
    end

    def work_attributes_key
      model.model_name.param_key
    end

    def param_hash
      @param_hash ||= parameter_builder.build
    end

    attr_reader :file_paths

    def params
      base = { work_attributes_key => param_hash }
      base[:uploaded_files] = file_uploader.uploaded_file_ids if file_paths.any?
      base
    end

    def file_uploader
      @file_uploader ||= FileUploader.new(file_paths, user)
    end

    def validate_form
      form.validate(params[work_attributes_key])
    end

    def action
      @action ||= Hyrax::Action::CreateValkyrieWork.new(
        form:,
        transactions:,
        user:,
        params:,
        work_attributes_key:
      )
    end

    def transactions
      Hyrax::Transactions::Container
    end

    def perform_action
      action.validate
      result = action.perform

      result.success? ? handle_success(result) : handle_failure(result)
    end

    def handle_success(result)
      self.work = result.value!
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
