# frozen_string_literal: true

module Skullrax
  module BatchCreate
    class FileInputsComponent < ViewComponent::Base
      def initialize(resource_type:, collection_value:, file_set_value:)
        @resource_type = resource_type
        @collection_value = collection_value
        @file_set_value = file_set_value
      end

      private

      attr_reader :resource_type, :collection_value, :file_set_value

      def render?
        resource_type != collection_value
      end

      def file_set?
        resource_type == file_set_value
      end

      def file_input_config # rubocop:disable Metrics/MethodLength
        if file_set?
          {
            title: t('hyrax.works.form.tab.files').singularize,
            name: 'resources[RESOURCE_ID][file]',
            label: t('skullrax.dashboard.batch_create.choose_file'),
            help: t('skullrax.dashboard.batch_create.file_required_help'),
            required: true,
            multiple: false
          }
        else
          {
            title: t('hyrax.works.form.tab.files'),
            name: 'resources[RESOURCE_ID][files][]',
            label: t('skullrax.dashboard.batch_create.choose_files'),
            help: t('skullrax.dashboard.batch_create.files_optional_help'),
            required: false,
            multiple: true
          }
        end
      end

      def remote_file_config # rubocop:disable Metrics/MethodLength
        if file_set?
          {
            field_name: 'remote_file',
            input_name: 'resources[RESOURCE_ID][remote_file]',
            input_id: 'RESOURCE_ID_remote_file',
            multi_value: false,
            label: 'Remote File (URL)',
            wrapper_classes: 'form-group string optional remote_file',
            label_classes: 'control-label string optional',
            input_classes: 'form-control string optional'
          }
        else
          {
            field_name: 'remote_files',
            input_name: 'resources[RESOURCE_ID][remote_files][]',
            input_id: 'RESOURCE_ID_remote_files',
            multi_value: true,
            label: 'Remote Files (URLs)',
            wrapper_classes: 'form-group multi_value optional remote_files',
            label_classes: 'control-label multi_value optional',
            input_classes: 'string multi_value optional form-control remote_files multi-text-field'
          }
        end
      end
    end
  end
end
