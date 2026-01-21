function initializeProcessResources() {
  const importFileInput = document.getElementById('import_file')
  const importSubmitButton = document.getElementById('import-submit')

  importFileInput.addEventListener('change', function() {
    if (importFileInput.files.length > 0) {
      importSubmitButton.removeAttribute('disabled');
    } else {
      importSubmitButton.setAttribute('disabled', 'disabled');
    }
  });
};

document.addEventListener('DOMContentLoaded', initializeProcessResources);
document.addEventListener('turbolinks:load', initializeProcessResources);
