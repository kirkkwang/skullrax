document.addEventListener('DOMContentLoaded', function() {
  const config = document.getElementById('batch-create-config');
  const COLLECTION_VALUE = config.dataset.collectionValue;
  const FILE_SET_VALUE = config.dataset.fileSetValue;

  const resourceTypeSelect = document.getElementById('resource-type');
  const resourcesList = document.getElementById('resources-list');
  const formsContainer = document.getElementById('forms-container');
  let resourceCounter = 0;

  resourceTypeSelect.addEventListener('change', function() {
    const selectedValue = this.value;
    const selectedText = this.options[this.selectedIndex].text;

    if (selectedValue) {
      const resourceId = addResource(selectedValue, selectedText);

      // Clear empty state if this is the first resource
      if (resourcesList.children.length === 1) {
        formsContainer.innerHTML = '';
      }

      showResourceForm(resourceId, selectedValue, selectedText);
      this.value = '';
    }
  });

  function createRemoveButton(text = 'Remove') {
    const removeBtn = document.createElement('button');
    removeBtn.type = 'button';
    removeBtn.className = 'btn btn-sm btn-link text-danger float-right';
    removeBtn.innerHTML = `<small>${text}</small>`;
    return removeBtn;
  }

  function addResource(value, displayText) {
    const resourceId = `resource-${resourceCounter++}`;

    // Clone template
    const template = document.getElementById('resource-item-template');
    const content = template.content.cloneNode(true);

    // Get the resource div and set dynamic attributes
    const resourceDiv = content.querySelector('.resource-item');
    resourceDiv.dataset.resourceId = resourceId;
    resourceDiv.dataset.resourceType = value;

    // Populate with data
    content.querySelector('.resource-label').textContent = displayText;
    const hiddenInput = content.querySelector('input[type="hidden"]');
    hiddenInput.name = `resources[${resourceId}][type]`;
    hiddenInput.value = value;

    resourcesList.appendChild(content);

    // Click to edit - attach after it's in the DOM
    resourcesList.querySelector(`[data-resource-id="${resourceId}"] .resource-label`).addEventListener('click', function() {
      scrollToResourceForm(resourceId);
    });

    // Remove resource - attach after it's in the DOM
    resourcesList.querySelector(`[data-resource-id="${resourceId}"] .remove-resource`).addEventListener('click', function(e) {
      e.stopPropagation();
      resourcesList.querySelector(`[data-resource-id="${resourceId}"]`).remove();

      // Also remove the form
      const formWrapper = document.getElementById(`resource-form-wrapper-${resourceId}`);
      if (formWrapper) {
        formWrapper.remove();
      }

      // Remove all nested children (works and filesets)
      const children = Array.from(formsContainer.children).filter(el =>
        el.dataset.parentId === resourceId
      );
      children.forEach(child => child.remove());

      // If no more resources, show empty state
      if (resourcesList.children.length === 0) {
        showEmptyState();
      }
    });

    // Show work type selector for Collections
    if (value === COLLECTION_VALUE) {
      const addWorkSection = resourcesList.querySelector(`[data-resource-id="${resourceId}"] .add-work-section`);
      addWorkSection.style.display = 'block';

      const workTypeSelect = addWorkSection.querySelector('.work-type-select');
      workTypeSelect.addEventListener('change', function() {
        const workType = this.value;
        const workTypeText = this.options[this.selectedIndex].text;

        if (workType) {
          addWork(resourceId, workType, workTypeText);
          this.value = ''; // Reset the select
        }
      });
    }

    // Add FileSet button click handler (for Works)
    if (value !== COLLECTION_VALUE) {
      const addFileSetBtn = resourcesList.querySelector(`[data-resource-id="${resourceId}"] .add-fileset-btn`);
      addFileSetBtn.style.display = 'block';
      addFileSetBtn.addEventListener('click', function(e) {
        e.stopPropagation();
        addFileSet(resourceId);
      });
    }

    return resourceId;
  }

  function addWork(parentCollectionId, workType, workTypeText) {
    const workId = `work-${resourceCounter++}`;

    // Clone template
    const template = document.getElementById('work-item-template');
    const content = template.content.cloneNode(true);

    // Get the work div and set attributes
    const workItem = content.querySelector('.work-item');
    workItem.dataset.workId = workId;
    workItem.dataset.parentId = parentCollectionId;
    workItem.dataset.workType = workType;

    // Set label
    content.querySelector('.work-label').textContent = workTypeText;

    // Update hidden input
    const hiddenInput = content.querySelector('input[type="hidden"]');
    hiddenInput.name = `resources[${parentCollectionId}][works][${workId}][type]`;
    hiddenInput.value = workType;

    // Add to nested works area
    const parentResourceDiv = resourcesList.querySelector(`[data-resource-id="${parentCollectionId}"]`);
    const nestedWorks = parentResourceDiv.querySelector('.nested-works');
    nestedWorks.appendChild(content);

    // Attach event handlers AFTER appending to DOM
    const addedWorkItem = nestedWorks.querySelector(`[data-work-id="${workId}"]`);

    // Click to show Work form
    addedWorkItem.querySelector('.work-label').addEventListener('click', function() {
      showWorkForm(workId, parentCollectionId, workType, workTypeText, true);
    });

    // Remove Work
    addedWorkItem.querySelector('.remove-work').addEventListener('click', function(e) {
      e.stopPropagation();
      addedWorkItem.remove();

      // Remove the work form
      const formWrapper = document.getElementById(`work-form-wrapper-${workId}`);
      if (formWrapper) {
        formWrapper.remove();
      }

      // Remove all FileSets that belong to this work
      const fileSetForms = Array.from(formsContainer.children).filter(el =>
        el.dataset.parentId === workId
      );
      fileSetForms.forEach(form => form.remove());
    });

    // Add FileSet button for this work
    addedWorkItem.querySelector('.add-fileset-btn').addEventListener('click', function(e) {
      e.stopPropagation();
      addFileSetToWork(workId, parentCollectionId);
    });

    showWorkForm(workId, parentCollectionId, workType, workTypeText);
  }

  function showWorkForm(workId, parentCollectionId, workType, workTypeText, shouldScroll = false) {
    let existingForm = document.getElementById(`work-form-wrapper-${workId}`);

    if (!existingForm) {
      const formTemplate = document.querySelector(`#form-templates .form-template[data-resource-type="${workType}"]`);

      if (!formTemplate) {
        console.error('No form template found for work type:', workType);
        return;
      }

      const clonedForm = formTemplate.cloneNode(true);

      const wrapper = document.createElement('div');
      wrapper.id = `work-form-wrapper-${workId}`;
      wrapper.className = 'mb-4 pb-4 border-bottom border-left pl-4';
      wrapper.dataset.parentId = parentCollectionId;
      wrapper.dataset.resourceType = 'work';

      // Add title with remove button
      const titleWrapper = document.createElement('div');
      titleWrapper.className = 'clearfix mb-3';

      const title = document.createElement('h5');
      title.textContent = workTypeText;
      title.className = 'float-left';

      const removeBtn = createRemoveButton();
      removeBtn.addEventListener('click', function() {
        // Remove from sidebar
        const sidebarItem = resourcesList.querySelector(`[data-work-id="${workId}"]`);
        if (sidebarItem) {
          sidebarItem.remove();
        }

        // Remove this form
        wrapper.remove();

        // Remove all nested filesets
        const fileSetForms = Array.from(formsContainer.children).filter(el =>
          el.dataset.parentId === workId
        );
        fileSetForms.forEach(form => form.remove());
      });

      titleWrapper.appendChild(title);
      titleWrapper.appendChild(removeBtn);
      wrapper.appendChild(titleWrapper);

      const inputs = clonedForm.querySelectorAll('input, select, textarea');
      inputs.forEach(input => {
        if (input.name) {
          input.name = input.name.replace(/^[^\[]+/, `resources[${parentCollectionId}][works][${workId}]`);
        }
        if (input.id) {
          input.id = `${workId}_${input.id}`;
        }
      });

      const labels = clonedForm.querySelectorAll('label');
      labels.forEach(label => {
        if (label.htmlFor) {
          label.htmlFor = `${workId}_${label.htmlFor}`;
        }
      });

      wrapper.appendChild(clonedForm);

      // Find the last WORK child of the parent collection (not filesets)
      const parentForm = document.getElementById(`resource-form-wrapper-${parentCollectionId}`);
      if (parentForm) {
        // Find all work siblings with the same parent (exclude filesets)
        const workSiblings = Array.from(formsContainer.children).filter(el =>
          el.dataset.parentId === parentCollectionId && el.dataset.resourceType === 'work'
        );

        if (workSiblings.length > 0) {
          // Find the last work's last descendant (could be the work itself or its last fileset)
          const lastWork = workSiblings[workSiblings.length - 1];
          const lastWorkId = lastWork.id.replace('work-form-wrapper-', '');

          // Find all descendants of this last work
          const lastWorkDescendants = Array.from(formsContainer.children).filter(el =>
            el.dataset.parentId === lastWorkId
          );

          if (lastWorkDescendants.length > 0) {
            // Insert after the last descendant
            lastWorkDescendants[lastWorkDescendants.length - 1].insertAdjacentElement('afterend', wrapper);
          } else {
            // No descendants, insert after the work itself
            lastWork.insertAdjacentElement('afterend', wrapper);
          }
        } else {
          // No work siblings yet, insert after parent
          parentForm.insertAdjacentElement('afterend', wrapper);
        }
      } else {
        formsContainer.appendChild(wrapper);
      }

      $(wrapper).find('.multi_value').manage_fields();

      if (shouldScroll) {
        scrollToForm(wrapper);
      }
    } else if (shouldScroll) {
      scrollToForm(existingForm);
    }

    initializeSecondaryFields(wrapper || existingForm);
    initializeVisibilityControls(wrapper || existingForm);
  }

  function addFileSetToWork(workId, parentCollectionId) {
    const fileSetId = `fileset-${resourceCounter++}`;

    const template = document.getElementById('fileset-item-template');
    const content = template.content.cloneNode(true);

    const fileSetItem = content.querySelector('.fileset-item');
    fileSetItem.dataset.filesetId = fileSetId;
    fileSetItem.dataset.parentId = workId;

    const hiddenInput = content.querySelector('input[type="hidden"]');
    hiddenInput.name = `resources[${parentCollectionId}][works][${workId}][filesets][${fileSetId}][type]`;
    hiddenInput.value = FILE_SET_VALUE;

    const workItem = resourcesList.querySelector(`[data-work-id="${workId}"]`);
    const nestedFilesets = workItem.querySelector('.nested-filesets');
    nestedFilesets.appendChild(content);

    const addedFileSetItem = nestedFilesets.querySelector(`[data-fileset-id="${fileSetId}"]`);

    addedFileSetItem.querySelector('.fileset-label').addEventListener('click', function() {
      showFileSetFormForWork(fileSetId, workId, parentCollectionId, true);
    });

    addedFileSetItem.querySelector('.remove-fileset').addEventListener('click', function(e) {
      e.stopPropagation();
      addedFileSetItem.remove();

      const formWrapper = document.getElementById(`fileset-form-wrapper-${fileSetId}`);
      if (formWrapper) {
        // For nested filesets, we need to remove the outerWrapper
        const outerWrapper = formWrapper.closest('.border-left.pl-4');
        if (outerWrapper) {
          outerWrapper.remove();
        } else {
          formWrapper.remove();
        }
      }
    });

    showFileSetFormForWork(fileSetId, workId, parentCollectionId);
  }

  function showFileSetFormForWork(fileSetId, parentWorkId, parentCollectionId, shouldScroll = false) {
    let existingForm = document.getElementById(`fileset-form-wrapper-${fileSetId}`);

    if (!existingForm) {
      const formTemplate = document.querySelector(`#form-templates .form-template[data-resource-type="${FILE_SET_VALUE}"]`);

      if (!formTemplate) {
        console.error('No FileSet form template found');
        return;
      }

      const clonedForm = formTemplate.cloneNode(true);

      const wrapper = document.createElement('div');
      wrapper.id = `fileset-form-wrapper-${fileSetId}`;
      wrapper.className = 'mb-4 pb-4 border-bottom';
      wrapper.dataset.parentId = parentWorkId;

      // Add title with remove button
      const titleWrapper = document.createElement('div');
      titleWrapper.className = 'clearfix mb-3';

      const title = document.createElement('h4');
      title.textContent = 'FileSet';
      title.className = 'float-left';

      const removeBtn = createRemoveButton();
      removeBtn.addEventListener('click', function() {
        // Remove from sidebar
        const sidebarItem = resourcesList.querySelector(`[data-fileset-id="${fileSetId}"]`);
        if (sidebarItem) {
          sidebarItem.remove();
        }

        // Remove this form (which is inside outerWrapper)
        outerWrapper.remove();
      });

      titleWrapper.appendChild(title);
      titleWrapper.appendChild(removeBtn);
      wrapper.appendChild(titleWrapper);

      const inputs = clonedForm.querySelectorAll('input, select, textarea');
      inputs.forEach(input => {
        if (input.name) {
          input.name = input.name.replace(/^[^\[]+/, `resources[${parentCollectionId}][works][${parentWorkId}][filesets][${fileSetId}]`);
        }
        if (input.id) {
          input.id = `${fileSetId}_${input.id}`;
        }
      });

      const labels = clonedForm.querySelectorAll('label');
      labels.forEach(label => {
        if (label.htmlFor) {
          label.htmlFor = `${fileSetId}_${label.htmlFor}`;
        }
      });

      wrapper.appendChild(clonedForm);

      // Wrap in double-border container
      const outerWrapper = document.createElement('div');
      outerWrapper.className = 'border-left pl-4';
      outerWrapper.dataset.parentId = parentWorkId;
      const innerWrapper = document.createElement('div');
      innerWrapper.className = 'border-left pl-4';
      innerWrapper.appendChild(wrapper);
      outerWrapper.appendChild(innerWrapper);

      // Find the last child of this parent (could be the work itself or its last fileset)
      const parentForm = document.getElementById(`work-form-wrapper-${parentWorkId}`);
      if (parentForm) {
        // Find all siblings with the same parent
        const siblings = Array.from(formsContainer.children).filter(el =>
          el.dataset.parentId === parentWorkId
        );

        if (siblings.length > 0) {
          // Insert after the last sibling
          siblings[siblings.length - 1].insertAdjacentElement('afterend', outerWrapper);
        } else {
          // No siblings yet, insert after parent
          parentForm.insertAdjacentElement('afterend', outerWrapper);
        }
      } else {
        formsContainer.appendChild(outerWrapper);
      }

      $(wrapper).find('.multi_value').manage_fields();

      if (shouldScroll) {
        scrollToForm(outerWrapper);
      }

      initializeSecondaryFields(wrapper);
      initializeVisibilityControls(wrapper);

    } else if (shouldScroll) {
      scrollToForm(existingForm);
    }
  }

  function scrollToResourceForm(resourceId) {
    const formWrapper = document.getElementById(`resource-form-wrapper-${resourceId}`);

    if (formWrapper) {
      const defaultHeaderHeight = 56;
      const elementPosition = formWrapper.getBoundingClientRect().top;
      const offsetPosition = elementPosition + window.pageYOffset - defaultHeaderHeight;

      window.scrollTo({
        top: offsetPosition,
        behavior: 'smooth'
      });
    }
  }

  function showResourceForm(resourceId, resourceType, displayText) {
    // Check if form already exists
    let existingForm = document.getElementById(`resource-form-wrapper-${resourceId}`);

    if (!existingForm) {
      // Find the template for this resource type
      const formTemplate = document.querySelector(`#form-templates .form-template[data-resource-type="${resourceType}"]`);

      if (!formTemplate) {
        console.error('No form template found for resource type:', resourceType);
        return;
      }

      // Clone the entire form
      const clonedForm = formTemplate.cloneNode(true);

      // Create wrapper
      const wrapper = document.createElement('div');
      wrapper.id = `resource-form-wrapper-${resourceId}`;
      wrapper.className = 'mb-4 pb-4 border-bottom';

      // Add title with remove button
      const titleWrapper = document.createElement('div');
      titleWrapper.className = 'clearfix mb-3';

      const title = document.createElement('h4');
      title.textContent = displayText;
      title.className = 'float-left';

      const removeBtn = createRemoveButton();
      removeBtn.addEventListener('click', function() {
        // Remove from sidebar
        const sidebarItem = resourcesList.querySelector(`[data-resource-id="${resourceId}"]`);
        if (sidebarItem) {
          sidebarItem.remove();
        }

        // Remove this form
        wrapper.remove();

        // Remove all nested children (works and filesets)
        const children = Array.from(formsContainer.children).filter(el =>
          el.dataset.parentId === resourceId
        );
        children.forEach(child => child.remove());

        // If no more resources, show empty state
        if (resourcesList.children.length === 0) {
          showEmptyState();
        }
      });

      titleWrapper.appendChild(title);
      titleWrapper.appendChild(removeBtn);
      wrapper.appendChild(titleWrapper);

      // Update all input names to use the resource ID
      const inputs = clonedForm.querySelectorAll('input, select, textarea');
      inputs.forEach(input => {
        if (input.name) {
          // Replace RESOURCE_ID placeholder or form name with our resources array structure
          input.name = input.name.replace('RESOURCE_ID', resourceId).replace(/^[^\[]+/, `resources[${resourceId}]`);
        }
        if (input.id) {
          input.id = `${resourceId}_${input.id}`;
        }
      });

      // Update all labels to point to the new IDs
      const labels = clonedForm.querySelectorAll('label');
      labels.forEach(label => {
        if (label.htmlFor) {
          label.htmlFor = `${resourceId}_${label.htmlFor}`;
        }
      });

      wrapper.appendChild(clonedForm);
      formsContainer.appendChild(wrapper);

      // Initialize the multi-value fields with hydra-editor
      $(wrapper).find('.multi_value').manage_fields();

      initializeSecondaryFields(wrapper);
      initializeVisibilityControls(wrapper);
    }
  }

  function showEmptyState() {
    const template = document.getElementById('empty-state-template');
    const content = template.content.cloneNode(true);

    formsContainer.innerHTML = '';
    formsContainer.appendChild(content);
  }

  function addFileSet(parentResourceId) {
    const fileSetId = `fileset-${resourceCounter++}`;

    // Clone template
    const template = document.getElementById('fileset-item-template');
    const content = template.content.cloneNode(true);

    // Get the fileset div and set attributes
    const fileSetItem = content.querySelector('.fileset-item');
    fileSetItem.dataset.filesetId = fileSetId;
    fileSetItem.dataset.parentId = parentResourceId;

    // Update hidden input
    const hiddenInput = content.querySelector('input[type="hidden"]');
    hiddenInput.name = `resources[${parentResourceId}][filesets][${fileSetId}][type]`;
    hiddenInput.value = FILE_SET_VALUE;

    // Add to nested filesets area
    const parentResourceDiv = resourcesList.querySelector(`[data-resource-id="${parentResourceId}"]`);
    const nestedFilesets = parentResourceDiv.querySelector('.nested-filesets');
    nestedFilesets.appendChild(content);

    // Attach event handlers AFTER appending to DOM
    const addedFileSetItem = nestedFilesets.querySelector(`[data-fileset-id="${fileSetId}"]`);

    // Click to show FileSet form
    addedFileSetItem.querySelector('.fileset-label').addEventListener('click', function() {
      showFileSetForm(fileSetId, parentResourceId, true);
    });

    // Remove FileSet
    addedFileSetItem.querySelector('.remove-fileset').addEventListener('click', function(e) {
      e.stopPropagation();
      addedFileSetItem.remove();

      // Remove the form too
      const formWrapper = document.getElementById(`fileset-form-wrapper-${fileSetId}`);
      if (formWrapper) {
        formWrapper.remove();
      }
    });

    // Create the form (without scrolling)
    showFileSetForm(fileSetId, parentResourceId);
  }

  function showFileSetForm(fileSetId, parentResourceId, shouldScroll = false) {
    let existingForm = document.getElementById(`fileset-form-wrapper-${fileSetId}`);

    if (!existingForm) {
      const formTemplate = document.querySelector(`#form-templates .form-template[data-resource-type="${FILE_SET_VALUE}"]`);

      if (!formTemplate) {
        console.error('No FileSet form template found');
        return;
      }

      const clonedForm = formTemplate.cloneNode(true);

      const wrapper = document.createElement('div');
      wrapper.id = `fileset-form-wrapper-${fileSetId}`;
      wrapper.className = 'mb-4 pb-4 border-bottom border-left pl-4';
      wrapper.dataset.parentId = parentResourceId;

      // Add title with remove button
      const titleWrapper = document.createElement('div');
      titleWrapper.className = 'clearfix mb-3';

      const title = document.createElement('h4');
      title.textContent = 'FileSet';
      title.className = 'float-left';

      const removeBtn = createRemoveButton();
      removeBtn.addEventListener('click', function() {
        // Remove from sidebar
        const sidebarItem = resourcesList.querySelector(`[data-fileset-id="${fileSetId}"]`);
        if (sidebarItem) {
          sidebarItem.remove();
        }

        // Remove this form
        wrapper.remove();
      });

      titleWrapper.appendChild(title);
      titleWrapper.appendChild(removeBtn);
      wrapper.appendChild(titleWrapper);

      const inputs = clonedForm.querySelectorAll('input, select, textarea');
      inputs.forEach(input => {
        if (input.name) {
          input.name = input.name.replace(/^[^\[]+/, `resources[${parentResourceId}][filesets][${fileSetId}]`);
        }
        if (input.id) {
          input.id = `${fileSetId}_${input.id}`;
        }
      });

      const labels = clonedForm.querySelectorAll('label');
      labels.forEach(label => {
        if (label.htmlFor) {
          label.htmlFor = `${fileSetId}_${label.htmlFor}`;
        }
      });

      wrapper.appendChild(clonedForm);

      // Find the last child of this parent
      const parentForm = document.getElementById(`resource-form-wrapper-${parentResourceId}`);
      if (parentForm) {
        // Find all siblings with the same parent
        const siblings = Array.from(formsContainer.children).filter(el =>
          el.dataset.parentId === parentResourceId
        );

        if (siblings.length > 0) {
          // Insert after the last sibling
          siblings[siblings.length - 1].insertAdjacentElement('afterend', wrapper);
        } else {
          // No siblings yet, insert after parent
          parentForm.insertAdjacentElement('afterend', wrapper);
        }
      } else {
        formsContainer.appendChild(wrapper);
      }

      $(wrapper).find('.multi_value').manage_fields();

      if (shouldScroll) {
        scrollToForm(wrapper);
      }

      initializeSecondaryFields(wrapper);
      initializeVisibilityControls(wrapper);
    } else if (shouldScroll) {
      scrollToForm(existingForm);
    }
  }

  function scrollToForm(wrapper) {
    const defaultHeaderHeight = 56;
    const elementPosition = wrapper.getBoundingClientRect().top;
    const offsetPosition = elementPosition + window.pageYOffset - defaultHeaderHeight;

    window.scrollTo({
      top: offsetPosition,
      behavior: 'smooth'
    });
  }

  function initializeSecondaryFields(formWrapper) {
    const dropdownMenu = formWrapper.querySelector('.secondary-field-selector');
    const secondaryTermsContainer = formWrapper.querySelector('.secondary-terms');
    const additionalFieldsSection = formWrapper.querySelector('.additional-fields-section');

    if (!dropdownMenu || !secondaryTermsContainer) return;

    // Helper function to add item in alphabetical order
    function addItemSorted(menu, fieldName, displayLabel) {
      const item = document.createElement('button');
      item.className = 'dropdown-item';
      item.type = 'button';
      item.dataset.fieldName = fieldName;
      item.textContent = displayLabel;

      // Find the right position to insert
      const items = Array.from(menu.querySelectorAll('.dropdown-item'));
      let inserted = false;

      for (let i = 0; i < items.length; i++) {
        if (item.textContent.localeCompare(items[i].textContent) < 0) {
          menu.insertBefore(item, items[i]);
          inserted = true;
          break;
        }
      }

      if (!inserted) {
        menu.appendChild(item);
      }

      return item;
    }

    // Build dropdown items from hidden fields
    const fieldWrappers = secondaryTermsContainer.querySelectorAll('.secondary-field-wrapper');
    fieldWrappers.forEach(wrapper => {
      const fieldName = wrapper.dataset.fieldName;

      // Try to find the label text from the rendered field
      const label = wrapper.querySelector('label');
      let displayLabel = fieldName.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase());

      if (label) {
        const labelClone = label.cloneNode(true);
        labelClone.querySelectorAll('.badge, .required-tag, span').forEach(el => el.remove());
        displayLabel = labelClone.textContent.trim();
      }

      const item = addItemSorted(dropdownMenu, fieldName, displayLabel);

      // Handle field selection
      item.addEventListener('click', function(e) {
        e.preventDefault();

        const fieldName = this.dataset.fieldName;
        const fieldWrapper = secondaryTermsContainer.querySelector(`[data-field-name="${fieldName}"]`);

        if (fieldWrapper) {
          // Create container with remove button
          const container = document.createElement('div');
          container.className = 'added-field mb-3 p-3 border rounded position-relative';
          container.dataset.fieldName = fieldName;

          const removeBtn = document.createElement('button');
          removeBtn.type = 'button';
          removeBtn.className = 'btn btn-sm btn-link text-danger position-absolute';
          removeBtn.style.top = '10px';
          removeBtn.style.right = '10px';
          removeBtn.innerHTML = '<small>Remove</small>';

          container.appendChild(removeBtn);
          container.appendChild(fieldWrapper);

          // Insert BEFORE the additional-fields-section instead of appending to it
          additionalFieldsSection.parentNode.insertBefore(container, additionalFieldsSection);

          // Remove from dropdown
          const displayLabel = this.textContent;
          this.remove();

          // Handle remove
          removeBtn.addEventListener('click', function() {
            // Move field back to hidden container
            secondaryTermsContainer.appendChild(fieldWrapper);

            // Remove the container
            container.remove();

            // Add back to dropdown (sorted)
            addItemSorted(dropdownMenu, fieldName, displayLabel);
          });

          // Initialize any multi-value fields that were just added
          $(container).find('.multi_value').manage_fields();
        }
      });
    });
  }

  function initializeVisibilityControls(formWrapper) {
    const visibilityRadios = formWrapper.querySelectorAll('.visibility-radio');

    visibilityRadios.forEach(radio => {
      radio.addEventListener('change', function() {
        const targetId = this.dataset.target;

        // Hide all embargo/lease fields in this form
        const embargoFields = formWrapper.querySelector('.embargo-fields');
        const leaseFields = formWrapper.querySelector('.lease-fields');

        if (embargoFields) {
          embargoFields.style.display = 'none';
          embargoFields.querySelectorAll('input, select').forEach(input => input.disabled = true);
        }

        if (leaseFields) {
          leaseFields.style.display = 'none';
          leaseFields.querySelectorAll('input, select').forEach(input => input.disabled = true);
        }

        // Show and enable the selected fields
        if (targetId && targetId !== 'none') {
          const targetFields = formWrapper.querySelector(`#${targetId}`);
          if (targetFields) {
            targetFields.style.display = 'block';
            targetFields.querySelectorAll('input, select').forEach(input => input.disabled = false);
          }
        }
      });
    });
  }
});
