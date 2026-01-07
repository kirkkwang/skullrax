# frozen_string_literal: true

module Skullrax
  class ImportCardComponent < ViewComponent::Base
    def import_path
      helpers.skullrax.imports_path
    end

    def file_accept_script # rubocop:disable Metrics/MethodLength
      content_tag(:script) do
        <<~JS.html_safe
          document.addEventListener('DOMContentLoaded', function() {
            const actionRadios = document.querySelectorAll('input[name="import[action]"]');
            const fileInput = document.querySelector('input[name="import[file]"]');

            function updateFileAccept() {
              const selectedAction = document.querySelector('input[name="import[action]"]:checked').value;

              if (selectedAction === 'create') {
                fileInput.setAttribute('accept', '.csv,.zip');
              } else {
                fileInput.setAttribute('accept', '.csv');
              }
            }

            actionRadios.forEach(radio => {
              radio.addEventListener('change', updateFileAccept);
            });

            updateFileAccept();
          });
        JS
      end
    end
  end
end
