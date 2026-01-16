document.addEventListener('DOMContentLoaded', () => {
  const CONFIG = {
    resourceTypeSelect: document.getElementById('resource-type'),
    resourcesList: document.getElementById('resources-list'),
    formsContainer: document.getElementById('forms-container'),
    collectionValue: document.getElementById('batch-create-config')?.dataset.collectionValue,
    fileSetValue: document.getElementById('batch-create-config')?.dataset.fileSetValue
  };

  let globalCounter = 0;

  class FormValidator {
    constructor() {
      this.submitButton = document.getElementById('submit-batch');
      this.formsContainer = document.getElementById('forms-container');
      this.autofillCheckbox = document.getElementById('autofill-checkbox');
      this.setupValidation();
    }

    setupValidation() {
      this.formsContainer.addEventListener('input', () => this.validateAllForms());
      this.formsContainer.addEventListener('change', () => this.validateAllForms());

      // Listen to autofill checkbox changes
      if (this.autofillCheckbox) {
        this.autofillCheckbox.addEventListener('change', () => this.validateAllForms());
      }
    }

    validateAllForms() {
      // If autofill is checked, enable button if there are any forms
      if (this.autofillCheckbox && this.autofillCheckbox.checked) {
        const forms = Array.from(this.formsContainer.querySelectorAll(
          '[id^="resource-form-wrapper-"], [id^="work-form-wrapper-"], [id^="fileset-form-wrapper-"]'
        ));
        this.submitButton.disabled = forms.length === 0;

        // Remove required attributes to bypass HTML5 validation
        this.formsContainer.querySelectorAll('[required]').forEach(field => {
          field.removeAttribute('required');
          field.dataset.wasRequired = 'true'; // Mark it so we can restore later
        });
        return;
      }

      // Restore required attributes when autofill is unchecked
      this.formsContainer.querySelectorAll('[data-was-required]').forEach(field => {
        field.setAttribute('required', 'required');
        delete field.dataset.wasRequired;
      });

      // Otherwise, validate normally
      const allValid = this.areAllFormsValid();
      this.submitButton.disabled = !allValid;
    }

    areAllFormsValid() {
      const forms = Array.from(this.formsContainer.querySelectorAll(
        '[id^="resource-form-wrapper-"], [id^="work-form-wrapper-"], [id^="fileset-form-wrapper-"]'
      ));

      if (forms.length === 0) return false;
      return forms.every(form => this.isFormValid(form));
    }

    isFormValid(form) {
      const requiredFields = form.querySelectorAll('[required]');

      // Group by name to handle multi-value fields
      const fieldsByName = {};
      Array.from(requiredFields).forEach(field => {
        if (!fieldsByName[field.name]) {
          fieldsByName[field.name] = [];
        }
        fieldsByName[field.name].push(field);
      });

      // Check each group - at least one must be valid
      return Object.values(fieldsByName).every(fields => {
        return fields.some(field => this.checkFieldValidity(field));
      });
    }

    checkFieldValidity(field) {
      if (field.type === 'file') {
        const wrapper = field.closest('.files-section');
        if (wrapper) {
          const remoteInput = wrapper.querySelector('input[type="url"]');
          return field.files.length > 0 || (remoteInput && remoteInput.value.trim());
        }
        return field.files.length > 0;
      }

      if (field.type === 'checkbox' || field.type === 'radio') {
        const name = field.name;
        const form = field.closest('form') || field.closest('[id$="-form-wrapper-"]');
        const checked = form.querySelector(`input[name="${name}"]:checked`);
        return !!checked;
      }

      return field.value.trim() !== '';
    }
  }

  const validator = new FormValidator();
  window.batchValidator = validator;

  class FormRenderer {
    static render(node, templateId, inputNamePrefix) {
      const formId = `${node.idPrefix}-form-wrapper-${node.id}`;
      let wrapper = document.getElementById(formId);

      if (wrapper) return wrapper;

      const template = document.querySelector(`#form-templates .form-template[data-resource-type="${node.type}"]`);
      if (!template) {
        console.error(`Template not found for type: ${node.type}`);
        return null;
      }

      const content = template.cloneNode(true);

      wrapper = document.createElement('div');
      wrapper.id = formId;
      wrapper.className = node.formWrapperClass;
      wrapper.dataset.parentId = node.parentId || '';
      wrapper.dataset.ownerId = node.id;

      const header = this.createHeader(node.displayText, () => node.remove());
      wrapper.appendChild(header);

      this.scopeInputs(content, node.id, inputNamePrefix);
      wrapper.appendChild(content);

      if (node.requiresOuterWrapper) {
        const outerWrapper = document.createElement('div');
        outerWrapper.className = 'border-left pl-4';
        outerWrapper.dataset.parentId = node.parentId;

        const innerWrapper = document.createElement('div');
        innerWrapper.className = 'border-left pl-4';
        innerWrapper.appendChild(wrapper);
        outerWrapper.appendChild(innerWrapper);

        this.injectIntoDOM(outerWrapper, node);

        this.initializeLogic(wrapper);
        return outerWrapper;
      }

      this.injectIntoDOM(wrapper, node);
      this.initializeLogic(wrapper);

      return wrapper;
    }

    static initializeLogic(wrapper) {
      if (window.jQuery) $(wrapper).find('.multi_value').manage_fields();
      this.initializeSecondaryFields(wrapper);
      this.initializeVisibilityControls(wrapper);
      this.initializeFileSetFileToggle(wrapper);

      if (window.batchValidator) window.batchValidator.validateAllForms();
    }

    static createHeader(text, removeCallback) {
      const div = document.createElement('div');
      div.className = 'clearfix mb-3';

      const title = document.createElement('h4');
      title.className = 'float-left';
      title.textContent = text;

      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'btn btn-sm btn-link text-danger float-right';
      btn.innerHTML = '<small>Remove</small>';
      btn.addEventListener('click', removeCallback);

      div.appendChild(title);
      div.appendChild(btn);
      return div;
    }

    static scopeInputs(container, id, namePrefix) {
      container.querySelectorAll('input, select, textarea').forEach(el => {
        if (el.name) {
          if (el.name.includes('[RESOURCE_ID]')) {
            // Replaces "resources[RESOURCE_ID]" with "resources[resource-0]"
            el.name = el.name.replace(/^[^\[]+\[RESOURCE_ID\]/, namePrefix);
          } else {
            // Fallback for standard inputs like "generic_work[title]" -> "resources[resource-0][title]"
            el.name = el.name.replace(/^[^\[]+/, namePrefix);
          }
        }

        if (el.id) {
          el.id = el.id.includes('RESOURCE_ID')
            ? el.id.replace(/RESOURCE_ID/g, id)
            : `${id}_${el.id}`;
        }

        if (el.dataset.target && el.dataset.target.includes('RESOURCE_ID')) {
          el.dataset.target = el.dataset.target.replace(/RESOURCE_ID/g, id);
        }

        if (el.hasAttribute('checked')) {
            el.checked = true;
        }
      });

      container.querySelectorAll('label').forEach(el => {
        if (el.htmlFor) {
          el.htmlFor = el.htmlFor.includes('RESOURCE_ID')
            ? el.htmlFor.replace(/RESOURCE_ID/g, id)
            : `${id}_${el.htmlFor}`;
        }
      });

      container.querySelectorAll('[id*="RESOURCE_ID"]').forEach(el => {
        el.id = el.id.replace(/RESOURCE_ID/g, id);
      });
    }

    static injectIntoDOM(wrapper, node) {
      const parentForm = document.querySelector(`[id$="-form-wrapper-${node.parentId}"]`);

      if (parentForm) {
        const siblings = Array.from(CONFIG.formsContainer.children).filter(el =>
          el.dataset.parentId === node.parentId
        );

        if (siblings.length > 0) {
          const lastSibling = siblings[siblings.length - 1];
          let lastSiblingId = lastSibling.dataset.ownerId;

          if (!lastSiblingId && lastSibling.querySelector('[data-owner-id]')) {
            lastSiblingId = lastSibling.querySelector('[data-owner-id]').dataset.ownerId;
          }

          const descendants = Array.from(CONFIG.formsContainer.children).filter(el =>
            el.dataset.parentId === lastSiblingId
          );

          if (descendants.length > 0) {
             descendants[descendants.length - 1].insertAdjacentElement('afterend', wrapper);
          } else {
             lastSibling.insertAdjacentElement('afterend', wrapper);
          }
        } else {
          parentForm.insertAdjacentElement('afterend', wrapper);
        }
      } else {
        CONFIG.formsContainer.appendChild(wrapper);
      }
    }

    static initializeSecondaryFields(formWrapper) {
      const dropdownMenu = formWrapper.querySelector('.secondary-field-selector');
      const secondaryTermsContainer = formWrapper.querySelector('.secondary-terms');
      const additionalFieldsSection = formWrapper.querySelector('.additional-fields-section');

      if (!dropdownMenu || !secondaryTermsContainer) return;

      const addItemSorted = (menu, fieldName, displayLabel) => {
        const item = document.createElement('button');
        item.className = 'dropdown-item';
        item.type = 'button';
        item.dataset.fieldName = fieldName;
        item.textContent = displayLabel;

        const items = Array.from(menu.querySelectorAll('.dropdown-item'));
        let inserted = false;

        for (let i = 0; i < items.length; i++) {
          if (item.textContent.localeCompare(items[i].textContent) < 0) {
            menu.insertBefore(item, items[i]);
            inserted = true;
            break;
          }
        }
        if (!inserted) menu.appendChild(item);
        return item;
      };

      const attachFieldClickHandler = (item, fieldName, displayLabel) => {
        item.addEventListener('click', function(e) {
          e.preventDefault();

          const currentFieldName = this.dataset.fieldName;
          const currentWrapper = secondaryTermsContainer.querySelector(`[data-field-name="${currentFieldName}"]`);

          if (currentWrapper) {
            const container = document.createElement('div');
            container.className = 'added-field mb-3 p-3 border rounded position-relative';
            container.dataset.fieldName = currentFieldName;

            const removeBtn = document.createElement('button');
            removeBtn.type = 'button';
            removeBtn.className = 'btn btn-sm btn-link text-danger position-absolute';
            removeBtn.style.top = '10px';
            removeBtn.style.right = '10px';
            removeBtn.innerHTML = '<small>Remove</small>';

            container.appendChild(removeBtn);
            container.appendChild(currentWrapper);

            additionalFieldsSection.parentNode.insertBefore(container, additionalFieldsSection);

            this.remove();

            removeBtn.addEventListener('click', () => {
              // Clear all inputs in this field before removing
              currentWrapper.querySelectorAll('input, textarea, select').forEach(input => {
                if (input.type === 'checkbox' || input.type === 'radio') {
                  input.checked = false;
                } else {
                  input.value = '';
                }
              });

              secondaryTermsContainer.appendChild(currentWrapper);
              container.remove();
              const newItem = addItemSorted(dropdownMenu, currentFieldName, displayLabel);
              attachFieldClickHandler(newItem, currentFieldName, displayLabel);
            });

            if (window.jQuery) $(container).find('.multi_value').manage_fields();
          }
        });
      };

      const fieldWrappers = secondaryTermsContainer.querySelectorAll('.secondary-field-wrapper');

      fieldWrappers.forEach(wrapper => {
        const fieldName = wrapper.dataset.fieldName;
        const label = wrapper.querySelector('label');
        let displayLabel = fieldName.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase());

        if (label) {
          const labelClone = label.cloneNode(true);
          labelClone.querySelectorAll('.badge, .required-tag, span').forEach(el => el.remove());
          displayLabel = labelClone.textContent.trim();
        }

        const item = addItemSorted(dropdownMenu, fieldName, displayLabel);
        attachFieldClickHandler(item, fieldName, displayLabel);
      });
    }

    static initializeVisibilityControls(formWrapper) {
      const visibilityRadios = formWrapper.querySelectorAll('.visibility-radio');

      visibilityRadios.forEach(radio => {
        radio.addEventListener('change', function() {
          const targetId = this.dataset.target;
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

    static initializeFileSetFileToggle(wrapper) {
      const fileInput = wrapper.querySelector('input[type="file"]');
      const urlInput = wrapper.querySelector('.remote_file input[type="url"]');

      if (!fileInput || !urlInput) return;

      // When file is selected, disable URL input
      fileInput.addEventListener('change', function() {
        if (this.files && this.files.length > 0) {
          urlInput.disabled = true;
          urlInput.value = '';
        } else {
          urlInput.disabled = false;
        }
      });

      // When URL is entered, disable file input
      urlInput.addEventListener('input', function() {
        if (this.value.trim()) {
          fileInput.disabled = true;
        } else {
          fileInput.disabled = false;
        }
      });
    }
  }

  class BatchNode {
    constructor({ type, displayText, parentId, inputPrefix, listContainer }) {
      this.id = `${this.idPrefix}-${globalCounter++}`;
      this.type = type;
      this.displayText = displayText;
      this.parentId = parentId;
      this.inputPrefix = `${inputPrefix}[${this.id}]`;
      this.listContainer = listContainer;
      this.element = this.createSidebarElement();
      this.mount();
    }

    get idPrefix() { throw new Error('Implement idPrefix'); }
    get templateId() { throw new Error('Implement templateId'); }
    get formWrapperClass() { return 'mb-4 pb-4 border-bottom'; }
    get requiresOuterWrapper() { return false; }

    createSidebarElement() {
      const template = document.getElementById(this.templateId);
      const content = template.content.cloneNode(true);

      let item, label, removeBtn;

      if (this.idPrefix === 'resource') {
        item = content.querySelector('.resource-item');
        label = content.querySelector('.resource-label');
        removeBtn = content.querySelector('.remove-resource');
        item.dataset.resourceId = this.id;
        item.dataset.resourceType = this.type;
      } else if (this.idPrefix === 'work') {
        item = content.querySelector('.work-item');
        label = content.querySelector('.work-label');
        removeBtn = content.querySelector('.remove-work');
        item.dataset.workId = this.id;
        item.dataset.parentId = this.parentId;
        item.dataset.workType = this.type;
      } else if (this.idPrefix === 'fileset') {
        item = content.querySelector('.fileset-item');
        label = content.querySelector('.fileset-label');
        removeBtn = content.querySelector('.remove-fileset');
        item.dataset.filesetId = this.id;
        item.dataset.parentId = this.parentId;
      }

      label.textContent = this.displayText;
      label.addEventListener('click', () => this.showForm(true));

      const hiddenInput = content.querySelector('input[type="hidden"]');
      if (hiddenInput) {
        hiddenInput.name = `${this.inputPrefix}[type]`;
        hiddenInput.value = this.type;
      }

      removeBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        this.remove();
      });

      return content;
    }

    mount() {
      this.listContainer.appendChild(this.element);

      if (this.idPrefix === 'resource') {
        this.domElement = this.listContainer.querySelector(`[data-resource-id="${this.id}"]`);
      } else if (this.idPrefix === 'work') {
        this.domElement = this.listContainer.querySelector(`[data-work-id="${this.id}"]`);
      } else {
        this.domElement = this.listContainer.querySelector(`[data-fileset-id="${this.id}"]`);
      }

      this.postMount();
      this.showForm(false);
    }

    postMount() {}

    showForm(shouldScroll = false) {
      const wrapper = FormRenderer.render(this, this.templateId, this.inputPrefix);
      if (shouldScroll && wrapper) {
        const offset = wrapper.getBoundingClientRect().top + window.pageYOffset - 56;
        window.scrollTo({ top: offset, behavior: 'smooth' });
      }
    }

    remove() {
      if (this.domElement) this.domElement.remove();

      const formId = `${this.idPrefix}-form-wrapper-${this.id}`;
      let formWrapper = document.getElementById(formId);

      if (formWrapper) {
        if (this.requiresOuterWrapper) {
            const outer = formWrapper.closest('.border-left.pl-4');
            if (outer && outer.contains(formWrapper)) {
                outer.remove();
            } else {
                formWrapper.remove();
            }
        } else {
            formWrapper.remove();
        }
      }

      this.removeDescendants(this.id);

      if (CONFIG.resourcesList.children.length === 0) {
        showEmptyState();
      }

      if (window.batchValidator) window.batchValidator.validateAllForms();
    }

    removeDescendants(parentId) {
      const children = Array.from(CONFIG.formsContainer.children).filter(el =>
        el.dataset.parentId === parentId
      );

      children.forEach(childForm => {
        let childId = childForm.dataset.ownerId;

        if (!childId) {
          const inner = childForm.querySelector('[data-owner-id]');
          if (inner) childId = inner.dataset.ownerId;
        }

        if (childId) {
          this.removeDescendants(childId);

          const sidebarItem =
            document.querySelector(`[data-work-id="${childId}"]`) ||
            document.querySelector(`[data-fileset-id="${childId}"]`);

          if (sidebarItem) sidebarItem.remove();
        }

        childForm.remove();
      });
    }
  }

  class ResourceNode extends BatchNode {
    get idPrefix() { return 'resource'; }
    get templateId() { return 'resource-item-template'; }

    postMount() {
      const isCollection = (this.type === CONFIG.collectionValue);

      if (isCollection) {
        const section = this.domElement.querySelector('.add-work-section');
        if (section) {
            section.style.display = 'block';
            const select = section.querySelector('.work-type-select');
            select.addEventListener('change', () => {
                if (!select.value) return;
                new WorkNode({
                    type: select.value,
                    displayText: select.options[select.selectedIndex].text,
                    parentId: this.id,
                    inputPrefix: `${this.inputPrefix}[works]`,
                    listContainer: this.domElement.querySelector('.nested-works')
                });
                select.value = '';
            });
        }
      } else {
        const addFsBtn = this.domElement.querySelector('.add-fileset-btn');
        if (addFsBtn) {
            addFsBtn.style.display = 'block';
            addFsBtn.addEventListener('click', (e) => {
                e.stopPropagation();
                new FileSetNode({
                    type: CONFIG.fileSetValue,
                    displayText: 'FileSet',
                    parentId: this.id,
                    inputPrefix: `${this.inputPrefix}[filesets]`,
                    listContainer: this.domElement.querySelector('.nested-filesets')
                });
            });
        }
      }
    }
  }

  class WorkNode extends BatchNode {
    get idPrefix() { return 'work'; }
    get templateId() { return 'work-item-template'; }
    get formWrapperClass() { return 'mb-4 pb-4 border-bottom border-left pl-4'; }

    postMount() {
      const addBtn = this.domElement.querySelector('.add-fileset-btn');
      if (addBtn) {
        addBtn.addEventListener('click', (e) => {
            e.stopPropagation();
            new FileSetNode({
                type: CONFIG.fileSetValue,
                displayText: 'FileSet',
                parentId: this.id,
                inputPrefix: `${this.inputPrefix}[filesets]`,
                listContainer: this.domElement.querySelector('.nested-filesets')
            });
        });
      }
    }
  }

  class FileSetNode extends BatchNode {
    get idPrefix() { return 'fileset'; }
    get templateId() { return 'fileset-item-template'; }
    get requiresOuterWrapper() {
      return this.parentId && this.parentId.startsWith('work-');
    }

    get formWrapperClass() {
      if (this.requiresOuterWrapper) {
        return 'mb-4 pb-4 border-bottom';
      } else {
        return 'mb-4 pb-4 border-bottom border-left pl-4';
      }
    }
  }

  function showEmptyState() {
    const template = document.getElementById('empty-state-template');
    CONFIG.formsContainer.innerHTML = '';
    CONFIG.formsContainer.appendChild(template.content.cloneNode(true));

    if (window.batchValidator) window.batchValidator.validateAllForms();
  }

  if (CONFIG.resourceTypeSelect) {
    CONFIG.resourceTypeSelect.addEventListener('change', function() {
      if (!this.value) return;

      if (CONFIG.resourcesList.children.length === 0) {
        CONFIG.formsContainer.innerHTML = '';
      }

      new ResourceNode({
        type: this.value,
        displayText: this.options[this.selectedIndex].text,
        parentId: null,
        inputPrefix: 'resources',
        listContainer: CONFIG.resourcesList
      });

      this.value = '';
    });
  }
});
