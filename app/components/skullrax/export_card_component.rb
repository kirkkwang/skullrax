# frozen_string_literal: true

module Skullrax
  class ExportCardComponent < ViewComponent::Base
    private

    def export_path
      helpers.skullrax.exports_path.split('?').first
    end

    def export_script
      content_tag(:script) do
        <<~JS.html_safe
          document.getElementById('export-link').addEventListener('click', function(e) {
            e.preventDefault();

            const ids = encodeURIComponent(document.getElementById('export_ids').value);
            const includeFiles = document.getElementById('export_include_files').checked ? '1' : '0';

            window.location.href = '#{export_path}?ids=' + ids + '&include_files=' + includeFiles;
          });
        JS
      end
    end
  end
end
