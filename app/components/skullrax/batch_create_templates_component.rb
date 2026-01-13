# frozen_string_literal: true

module Skullrax
  class BatchCreateTemplatesComponent < ViewComponent::Base
    attr_reader :work_options

    def initialize(work_options:)
      @work_options = work_options
    end

    def resource_item_template # rubocop:disable Metrics/MethodLength
      content_tag(:template, id: 'resource-item-template') do
        <<~HTML.html_safe
          <div class="resource-item border rounded p-2 mb-2" style="cursor: pointer;">
            <div class="d-flex justify-content-between align-items-center">
              <span class="resource-label"></span>
              <button type="button" class="btn btn-sm btn-link text-danger remove-resource">#{t('skullrax.dashboard.batch_create.remove')}</button>
            </div>
            <div class="nested-works ml-3"></div>
            <div class="add-work-section mt-2" style="display: none;">
              <select class="form-control form-control-sm work-type-select">
                <option value="">#{t('skullrax.dashboard.batch_create.select_work_type')}</option>
                #{work_options}
              </select>
            </div>
            <div class="nested-filesets ml-3"></div>
            <button type="button" class="btn btn-sm btn-secondary add-fileset-btn mt-2" style="display: none;">
              <span class="fa fa-plus"></span> Add FileSet
            </button>
            <input type="hidden" name="" value="">
          </div>
        HTML
      end
    end

    def work_item_template # rubocop:disable Metrics/MethodLength
      content_tag(:template, id: 'work-item-template') do
        <<~HTML.html_safe
          <div class="work-item border-left pl-2 py-1">
            <div class="d-flex justify-content-between align-items-center">
              <small class="work-label" style="cursor: pointer;"></small>
              <button type="button" class="btn btn-sm btn-link text-danger remove-work">
                <small>#{t('skullrax.dashboard.batch_create.remove')}</small>
              </button>
            </div>
            <div class="nested-filesets ml-2"></div>
              <button type="button" class="btn btn-sm btn-secondary add-fileset-btn mt-1" style="font-size: 0.875rem;">
                <span class="fa fa-plus"></span> #{t('skullrax.dashboard.batch_create.add_fileset')}
              </button>
            <input type="hidden" name="" value="">
          </div>
        HTML
      end
    end

    def fileset_item_template # rubocop:disable Metrics/MethodLength
      content_tag(:template, id: 'fileset-item-template') do
        <<~HTML.html_safe
          <div class="fileset-item border-left pl-2 py-1">
            <div class="d-flex justify-content-between align-items-center">
              <small class="fileset-label" style="cursor: pointer;">FileSet</small>
              <button type="button" class="btn btn-sm btn-link text-danger remove-fileset">
                <small>#{t('skullrax.dashboard.batch_create.remove')}</small>
              </button>
            </div>
            <input type="hidden" name="" value="">
          </div>
        HTML
      end
    end

    def empty_state_template
      content_tag(:template, id: 'empty-state-template') do
        <<~HTML.html_safe
          <div class="text-muted text-center py-5">
            <p>#{t('skullrax.dashboard.batch_create.select_to_begin')}</p>
          </div>
        HTML
      end
    end
  end
end
