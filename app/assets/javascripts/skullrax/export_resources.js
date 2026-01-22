function initializeExportResources() {
  const exportIdsInput = document.getElementById('export_ids');
  const exportIdsLinkButton = document.getElementById('export-link');

  if (!exportIdsInput || !exportIdsLinkButton) return;

  exportIdsInput.addEventListener('input', function() {
    if (exportIdsInput.value.trim().length > 0) {
      exportIdsLinkButton.classList.remove('disabled');
      exportIdsLinkButton.style.pointerEvents = 'auto';
    } else {
      exportIdsLinkButton.classList.add('disabled');
      exportIdsLinkButton.style.pointerEvents = 'none';
    }
  });

  exportIdsLinkButton.addEventListener('click', function(e) {
    e.preventDefault();

    const ids = encodeURIComponent(document.getElementById('export_ids').value);
    const includeFiles = document.getElementById('export_include_files').checked ? '1' : '0';
    const exportPath = exportIdsLinkButton.getAttribute('data-export-path');

    window.location.href = exportPath + '?ids=' + ids + '&include_files=' + includeFiles;
  });
}

document.addEventListener('DOMContentLoaded', initializeExportResources);
document.addEventListener('turbolinks:load', initializeExportResources);
