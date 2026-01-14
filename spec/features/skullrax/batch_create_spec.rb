# frozen_string_literal: true

RSpec.feature 'Batch Create Interface', js: true do
  include Devise::Test::IntegrationHelpers

  let(:admin) { create(:admin, email: 'admin@example.com') }

  before do
    sign_in admin
    visit skullrax.root_path
  end

  describe 'adding resources' do
    scenario 'adding a collection creates a sidebar item and form' do
      add_collection

      expect(page).to have_css('#resources-list .resource-item', count: 1)
      expect(page).to have_css('#forms-container [id^="resource-form-wrapper-"]')
    end

    scenario 'adding a work creates a sidebar item and form' do
      add_work('Generic Work')

      expect(page).to have_css('#resources-list .resource-item', count: 1)
      expect(page).to have_css('#forms-container [id^="resource-form-wrapper-"]')
    end

    scenario 'adding multiple top-level resources creates multiple items' do
      add_collection
      add_work('Generic Work')
      add_collection

      expect(page).to have_css('#resources-list .resource-item', count: 3)
      expect(page).to have_css('#forms-container [id^="resource-form-wrapper-"]', count: 3)
    end
  end

  describe 'nesting works under collections' do
    scenario 'adding a work to a collection shows work type selector' do
      add_collection

      within '#resources-list [data-resource-id="resource-0"]' do
        expect(page).to have_css('.add-work-section', visible: true)
      end
    end

    scenario 'selecting a work type adds nested work to sidebar and creates form' do
      add_collection

      add_nested_work_to_collection('#resources-list [data-resource-id="resource-0"]', 'Generic Work')

      expect(page).to have_css('.work-item[data-work-id]')
      expect(page).to have_css('#forms-container [id^="work-form-wrapper-"]')
    end

    scenario 'adding multiple works to a collection creates multiple nested items' do
      add_collection

      add_nested_work_to_collection('#resources-list [data-resource-id="resource-0"]', 'Generic Work')
      add_nested_work_to_collection('#resources-list [data-resource-id="resource-0"]', 'Monograph')

      expect(page).to have_css('.work-item', count: 2)
      expect(page).to have_css('#forms-container [id^="work-form-wrapper-"]', count: 2)
    end
  end

  describe 'nesting filesets under works' do
    scenario 'top-level work shows Add FileSet button' do
      add_work('Generic Work')

      within '#resources-list [data-resource-id="resource-0"]' do
        expect(page).to have_button('Add FileSet')
      end
    end

    scenario 'clicking Add FileSet on top-level work creates nested fileset' do
      add_work('Generic Work')

      add_fileset_to_work('#resources-list [data-resource-id="resource-0"]')

      expect(page).to have_css('.fileset-item[data-fileset-id]')
      expect(page).to have_css('#forms-container [id^="fileset-form-wrapper-"]')
    end

    scenario 'nested work under collection shows Add FileSet button' do
      add_collection

      add_nested_work_to_collection('#resources-list [data-resource-id="resource-0"]', 'Generic Work')

      within '.work-item[data-work-id="work-1"]' do
        expect(page).to have_button('Add FileSet')
      end
    end

    scenario 'adding fileset to nested work creates nested fileset' do
      add_collection

      add_nested_work_to_collection('#resources-list [data-resource-id="resource-0"]', 'Generic Work')

      add_fileset_to_work('.work-item[data-work-id="work-1"]')

      expect(page).to have_css('.fileset-item[data-fileset-id]')
      expect(page).to have_css('#forms-container [id^="fileset-form-wrapper-"]')
    end

    scenario 'adding multiple filesets to a work creates multiple items' do
      add_work('Generic Work')

      within '#resources-list [data-resource-id="resource-0"]' do
        click_button 'Add FileSet'
        click_button 'Add FileSet'
        click_button 'Add FileSet'
      end

      expect(page).to have_css('.fileset-item', count: 3)
      expect(page).to have_css('#forms-container [id^="fileset-form-wrapper-"]', count: 3)
    end
  end

  describe 'form ordering' do
    scenario 'adding two collections keeps them in order' do
      add_collection
      add_collection

      forms = page.all('#forms-container > div[id^="resource-form-wrapper-"]')
      expect(forms[0][:id]).to eq('resource-form-wrapper-resource-0')
      expect(forms[1][:id]).to eq('resource-form-wrapper-resource-1')
    end

    scenario 'nested works appear after their parent collection' do
      add_collection

      add_nested_work_to_collection('#resources-list [data-resource-id="resource-0"]', 'Generic Work')

      forms = page.all('#forms-container > div')
      expect(forms[0][:id]).to eq('resource-form-wrapper-resource-0')
      expect(forms[1][:id]).to eq('work-form-wrapper-work-1')
    end

    scenario 'multiple nested works stay in order after their parent' do
      add_collection

      add_nested_work_to_collection('#resources-list [data-resource-id="resource-0"]', 'Generic Work')
      add_nested_work_to_collection('#resources-list [data-resource-id="resource-0"]', 'Monograph')

      forms = page.all('#forms-container > div')
      expect(forms[0][:id]).to eq('resource-form-wrapper-resource-0')
      expect(forms[1][:id]).to eq('work-form-wrapper-work-1')
      expect(forms[2][:id]).to eq('work-form-wrapper-work-2')
    end

    scenario 'filesets appear after their parent work' do
      add_work('Generic Work')

      add_fileset_to_work('#resources-list [data-resource-id="resource-0"]')

      forms = page.all('#forms-container > div')
      expect(forms[0][:id]).to eq('resource-form-wrapper-resource-0')
      expect(forms[1][:id]).to eq('fileset-form-wrapper-fileset-1')
    end

    scenario 'multiple filesets stay in order after their parent work' do
      add_work('Generic Work')

      within '#resources-list [data-resource-id="resource-0"]' do
        click_button 'Add FileSet'
        click_button 'Add FileSet'
      end

      forms = page.all('#forms-container > div')
      expect(forms[0][:id]).to eq('resource-form-wrapper-resource-0')
      expect(forms[1][:id]).to eq('fileset-form-wrapper-fileset-1')
      expect(forms[2][:id]).to eq('fileset-form-wrapper-fileset-2')
    end

    scenario 'complex hierarchy maintains correct order: collection > work > fileset, then another work' do
      add_collection

      add_nested_work_to_collection('#resources-list [data-resource-id="resource-0"]', 'Generic Work')

      add_fileset_to_work('.work-item[data-work-id="work-1"]')

      add_nested_work_to_collection('#resources-list [data-resource-id="resource-0"]', 'Monograph')

      forms = page.all(
        '#forms-container > div[id^="resource-form-wrapper-"], #forms-container > div[id^="work-form-wrapper-"]'
      )

      expect(forms[0][:id]).to eq('resource-form-wrapper-resource-0') # Collection
      expect(forms[1][:id]).to eq('work-form-wrapper-work-1')         # First work
      expect(forms[2][:id]).to eq('work-form-wrapper-work-3')         # Second work
    end

    scenario 'adding second work after first work has filesets puts new work after all filesets' do
      add_collection

      add_nested_work_to_collection('#resources-list [data-resource-id="resource-0"]', 'Generic Work')

      within '.work-item[data-work-id="work-1"]' do
        click_button 'Add FileSet'
        click_button 'Add FileSet'
      end

      add_nested_work_to_collection('#resources-list [data-resource-id="resource-0"]', 'Monograph')

      # Get all top-level forms
      forms = page.all(
        '#forms-container > div[id^="resource-form-wrapper-"], #forms-container > div[id^="work-form-wrapper-"]'
      )

      expect(forms.last[:id]).to match(/^work-form-wrapper-work-\d+$/) # New work is last
    end
  end

  describe 'removing resources from sidebar' do
    scenario 'removing a top-level collection removes sidebar item and form' do
      add_collection

      within '#resources-list [data-resource-id="resource-0"]' do
        find('.remove-resource').click
      end

      expect(page).not_to have_css('#resources-list .resource-item')
      expect(page).not_to have_css('#forms-container [id^="resource-form-wrapper-"]')
    end

    scenario 'removing a top-level work removes sidebar item and form' do
      add_work('Generic Work')

      within '#resources-list [data-resource-id="resource-0"]' do
        find('.remove-resource').click
      end

      expect(page).not_to have_css('#resources-list .resource-item')
      expect(page).not_to have_css('#forms-container [id^="resource-form-wrapper-"]')
    end

    scenario 'removing a work with filesets also removes all filesets' do
      add_work('Generic Work')

      within '#resources-list [data-resource-id="resource-0"]' do
        click_button 'Add FileSet'
        click_button 'Add FileSet'
      end

      within '#resources-list [data-resource-id="resource-0"]' do
        find('.remove-resource').click
      end

      expect(page).not_to have_css('.fileset-item')
      expect(page).not_to have_css('#forms-container [id^="fileset-form-wrapper-"]')
    end

    scenario 'removing one collection does not leave orphaned filesets' do
      add_collection

      add_nested_work_to_collection('#resources-list [data-resource-id="resource-0"]', 'Generic Work')
      add_fileset_to_work('.work-item[data-work-id="work-1"]')

      add_collection
      add_nested_work_to_collection('#resources-list [data-resource-id="resource-3"]', 'Generic Work')
      add_fileset_to_work('.work-item[data-work-id="work-4"]')

      expect(page).to have_css('.fileset-item', count: 2)

      within '#resources-list [data-resource-id="resource-0"]' do
        find('.remove-resource').click
      end

      expect(page).not_to have_css('#forms-container #resource-form-wrapper-resource-0')
      expect(page).not_to have_css('#forms-container #work-form-wrapper-work-1')
      # [THE BUG]: Without recursive delete, this form usually remains orphaned in the DOM
      expect(page).not_to have_css('#forms-container #fileset-form-wrapper-fileset-2')

      expect(page).to have_css('#forms-container #resource-form-wrapper-resource-3')
      expect(page).to have_css('#forms-container #work-form-wrapper-work-4')
      expect(page).to have_css('#forms-container #fileset-form-wrapper-fileset-5')
    end

    scenario 'removing a nested work removes it but keeps parent collection' do
      add_collection

      add_nested_work_to_collection('#resources-list [data-resource-id="resource-0"]', 'Generic Work')

      within '.work-item[data-work-id="work-1"]' do
        find('.remove-work').click
      end

      expect(page).not_to have_css('.work-item')
      expect(page).not_to have_css('#forms-container [id^="work-form-wrapper-"]')
      expect(page).to have_css('#resources-list .resource-item') # Collection still there
    end

    scenario 'removing a nested work with filesets also removes its filesets' do
      add_collection

      add_nested_work_to_collection('#resources-list [data-resource-id="resource-0"]', 'Generic Work')

      within '.work-item[data-work-id="work-1"]' do
        click_button 'Add FileSet'
        click_button 'Add FileSet'
      end

      within '.work-item[data-work-id="work-1"]' do
        find('.remove-work').click
      end

      expect(page).not_to have_css('.fileset-item')
      expect(page).not_to have_css('#forms-container [id^="fileset-form-wrapper-"]')
    end

    scenario 'removing a fileset removes it but keeps parent work' do
      add_work('Generic Work')

      within '#resources-list [data-resource-id="resource-0"]' do
        click_button 'Add FileSet'
        click_button 'Add FileSet'
      end

      within first('.fileset-item') do
        find('.remove-fileset').click
      end

      expect(page).to have_css('.fileset-item', count: 1)
      expect(page).to have_css('#resources-list .resource-item') # Work still there
    end
  end

  describe 'removing resources from form remove button' do
    scenario 'clicking remove button on collection form removes sidebar item and form' do
      add_collection

      within '#forms-container #resource-form-wrapper-resource-0' do
        find('button', text: 'Remove', match: :first).click
      end

      expect(page).not_to have_css('#resources-list .resource-item')
      expect(page).not_to have_css('#forms-container [id^="resource-form-wrapper-"]')
    end

    scenario 'clicking remove button on work form removes sidebar item and form' do
      add_collection

      add_nested_work_to_collection('#resources-list [data-resource-id="resource-0"]', 'Generic Work')

      within '#forms-container #work-form-wrapper-work-1' do
        # The remove button is in the title wrapper at the top of the form
        find('button.btn-link.text-danger', text: 'Remove').click
      end

      expect(page).not_to have_css('.work-item')
      expect(page).not_to have_css('#forms-container [id^="work-form-wrapper-"]')
      expect(page).to have_css('#resources-list .resource-item') # Collection still there
    end

    scenario 'clicking remove button on fileset form removes sidebar item and form' do
      add_work('Generic Work')

      add_fileset_to_work('#resources-list [data-resource-id="resource-0"]')

      within '#forms-container #fileset-form-wrapper-fileset-1' do
        # The remove button is in the title wrapper at the top of the form
        find('button.btn-link.text-danger', text: 'Remove').click
      end

      expect(page).not_to have_css('.fileset-item')
      expect(page).not_to have_css('#forms-container [id^="fileset-form-wrapper-"]')
      expect(page).to have_css('#resources-list .resource-item') # Work still there
    end
  end

  describe 'adding and removing secondary fields' do
    scenario 'clicking Additional fields dropdown shows available fields' do
      add_work('Generic Work')

      within '#forms-container #resource-form-wrapper-resource-0' do
        click_button 'Additional fields'
        expect(page).to have_css('.dropdown-menu .dropdown-item')
      end
    end

    scenario 'adding a secondary field removes it from dropdown and shows the field' do
      add_work('Generic Work')

      within '#forms-container #resource-form-wrapper-resource-0' do
        click_button 'Additional fields'
        first('.dropdown-item').click

        expect(page).to have_css('.added-field', count: 1)
      end
    end

    scenario 'removing a secondary field adds it back to dropdown and hides the field' do
      add_work('Generic Work')

      within '#forms-container #resource-form-wrapper-resource-0' do
        click_button 'Additional fields'
        first_field_text = first('.dropdown-item').text
        first('.dropdown-item').click

        within '.added-field' do
          find('button', text: 'Remove').click
        end

        click_button 'Additional fields'
        expect(page).to have_content(first_field_text)
      end
    end
  end

  describe 'visibility controls' do
    scenario 'selecting embargo shows embargo fields' do
      add_work('Generic Work')

      within '#forms-container #resource-form-wrapper-resource-0' do
        # Find by value instead of ID since IDs are dynamic
        find('input[type="radio"][value="embargo"]', visible: :all).click

        expect(page).to have_css('.embargo-fields', visible: true)
      end
    end

    scenario 'selecting lease shows lease fields' do
      add_work('Generic Work')

      within '#forms-container #resource-form-wrapper-resource-0' do
        find('input[type="radio"][value="lease"]', visible: :all).click

        expect(page).to have_css('.lease-fields', visible: true)
      end
    end

    scenario 'switching from embargo to public hides embargo fields' do
      add_work('Generic Work')

      within '#forms-container #resource-form-wrapper-resource-0' do
        find('input[type="radio"][value="embargo"]', visible: :all).click
        expect(page).to have_css('.embargo-fields', visible: true)

        find('input[type="radio"][value="open"]', visible: :all).click
        expect(page).to have_css('.embargo-fields', visible: false)
      end
    end

    scenario 'visibility defaults to private/restricted' do
      add_work('Generic Work')

      within '#forms-container #resource-form-wrapper-resource-0' do
        # Check that restricted radio is selected by default
        restricted_radio = find('input[type="radio"][value="restricted"]', visible: :all)
        expect(restricted_radio).to be_checked

        # Verify other options are not checked
        expect(find('input[type="radio"][value="open"]', visible: :all)).not_to be_checked
        expect(find('input[type="radio"][value="authenticated"]', visible: :all)).not_to be_checked
      end
    end

    scenario 'each form has independent visibility selection' do
      add_work('Generic Work')
      add_collection

      # First work defaults to restricted
      within '#forms-container #resource-form-wrapper-resource-0' do
        expect(find('input[type="radio"][value="restricted"]', visible: :all)).to be_checked
      end

      # Second collection also defaults to restricted
      within '#forms-container #resource-form-wrapper-resource-1' do
        expect(find('input[type="radio"][value="restricted"]', visible: :all)).to be_checked
      end

      # Change first work to open
      within '#forms-container #resource-form-wrapper-resource-0' do
        find('input[type="radio"][value="open"]', visible: :all).click
      end

      # Second collection should still be restricted
      within '#forms-container #resource-form-wrapper-resource-1' do
        expect(find('input[type="radio"][value="restricted"]', visible: :all)).to be_checked
      end
    end
  end

  describe 'admin set selection' do
    scenario 'admin set dropdown appears for top-level works' do
      add_work('Generic Work')

      within '#forms-container #resource-form-wrapper-resource-0' do
        expect(page).to have_css('.admin-set-section', visible: true)
        expect(page).to have_select('resources[resource-0][admin_set_id]')
      end
    end

    scenario 'admin set dropdown appears for nested works' do
      add_collection
      add_nested_work_to_collection('#resources-list [data-resource-id="resource-0"]', 'Generic Work')

      within '#forms-container #work-form-wrapper-work-1' do
        expect(page).to have_css('.admin-set-section', visible: true)
        expect(page).to have_select('resources[resource-0][works][work-1][admin_set_id]')
      end
    end

    scenario 'admin set dropdown does NOT appear for collections' do
      add_collection

      within '#forms-container #resource-form-wrapper-resource-0' do
        expect(page).not_to have_css('.admin-set-section')
        expect(page).not_to have_css('select.admin-set-select')
      end
    end

    scenario 'admin set dropdown does NOT appear for filesets' do
      add_work('Generic Work')
      add_fileset_to_work('#resources-list [data-resource-id="resource-0"]')

      within '#forms-container #resource-form-wrapper-resource-0' do
        expect(page).to have_css('.admin-set-section')
      end

      within '#forms-container #fileset-form-wrapper-fileset-1' do
        expect(page).not_to have_css('.admin-set-section')
        expect(page).not_to have_css('select.admin-set-select')
      end
    end

    scenario 'default admin set is pre-selected' do
      default_set_id = valkyrie_create(:hyrax_admin_set, title: 'Default Admin Set').id
      create(:permission_template, source_id: default_set_id, deposit_users: [admin])

      other_set_id = valkyrie_create(:hyrax_admin_set, title: 'Some Other Admin Set').id
      create(:permission_template, source_id: other_set_id, deposit_users: [admin])

      visit skullrax.root_path

      add_work('Generic Work')

      within '#forms-container #resource-form-wrapper-resource-0' do
        expect(page).to have_select('resources[resource-0][admin_set_id]',
                                    options: ['Default Admin Set', 'Some Other Admin Set'])

        expect(page).to have_select('resources[resource-0][admin_set_id]',
                                    selected: 'Default Admin Set')
      end
    end
  end

  describe 'remote files' do
    scenario 'works show multi-value remote files field' do
      add_work('Generic Work')

      within '#forms-container #resource-form-wrapper-resource-0' do
        expect(page).to have_css('.remote_files')
        expect(page).to have_field('resources[resource-0][remote_files][]', type: 'url')
        expect(page).to have_button('Add another Remote Files (URLs)')
      end
    end

    scenario 'adding multiple remote files to a work' do
      add_work('Generic Work')

      within '#forms-container #resource-form-wrapper-resource-0' do
        fill_in 'resources[resource-0][remote_files][]', with: 'https://example.com/image1.jpg'
        click_button 'Add another Remote Files (URLs)'

        # Find the second input that was added
        inputs = all('input[name="resources[resource-0][remote_files][]"]')
        expect(inputs.count).to eq(2)

        inputs.last.fill_in with: 'https://example.com/image2.jpg'
      end
    end

    scenario 'filesets show single remote file field' do
      add_work('Generic Work')
      add_fileset_to_work('#resources-list [data-resource-id="resource-0"]')

      within '#forms-container #fileset-form-wrapper-fileset-1' do
        expect(page).to have_css('.remote_file')
        expect(page).to have_field('resources[resource-0][filesets][fileset-1][remote_file]', type: 'url')
        expect(page).not_to have_css('.remote_file.multi_value')
      end
    end

    scenario 'fileset file upload disables when remote URL is entered' do
      add_work('Generic Work')
      add_fileset_to_work('#resources-list [data-resource-id="resource-0"]')

      within '#forms-container #fileset-form-wrapper-fileset-1' do
        file_input = find('input[type="file"]', match: :first)
        url_input = find('input[type="url"]')

        expect(file_input).not_to be_disabled
        expect(url_input).not_to be_disabled

        # Enter URL
        url_input.fill_in with: 'https://example.com/image.jpg'

        expect(file_input).to be_disabled
        expect(url_input).not_to be_disabled
      end
    end

    scenario 'fileset remote URL disables when file is selected' do
      add_work('Generic Work')
      add_fileset_to_work('#resources-list [data-resource-id="resource-0"]')

      within '#forms-container #fileset-form-wrapper-fileset-1' do
        file_input = find('input[type="file"]', match: :first)
        url_input = find('input[type="url"]')

        # Attach a file
        file_input.attach_file(Skullrax.root.join('spec', 'fixtures', 'files', 'test_file.png'))

        expect(file_input).not_to be_disabled
        expect(url_input).to be_disabled
        expect(url_input.value).to be_empty
      end
    end

    scenario 'fileset clearing remote URL re-enables file upload' do
      add_work('Generic Work')
      add_fileset_to_work('#resources-list [data-resource-id="resource-0"]')

      within '#forms-container #fileset-form-wrapper-fileset-1' do
        file_input = find('input[type="file"]', match: :first)
        url_input = find('input[type="url"]')

        # Enter and then clear URL
        url_input.fill_in with: 'https://example.com/image.jpg'
        expect(file_input).to be_disabled

        url_input.fill_in with: ''
        expect(file_input).not_to be_disabled
      end
    end
  end

  describe 'form validation and submit button' do
    let(:submit_button) { find('#submit-batch') }

    scenario 'submit button starts disabled' do
      expect(submit_button).to be_disabled
    end

    scenario 'submit button stays disabled with empty forms' do
      add_collection

      expect(submit_button).to be_disabled
    end

    scenario 'submit button enables when collection form is filled' do
      add_collection

      within '#forms-container #resource-form-wrapper-resource-0' do
        fill_in 'resources[resource-0][title][]', with: 'My Collection'
        fill_in 'resources[resource-0][creator][]', with: 'Collection Creator'
      end

      expect(submit_button).not_to be_disabled
    end

    scenario 'submit button enables when work form is filled' do
      add_work('Generic Work')

      within '#forms-container #resource-form-wrapper-resource-0' do
        fill_in 'resources[resource-0][title][]', with: 'My Work'
        fill_in 'resources[resource-0][creator][]', with: 'Test Creator'
      end

      expect(submit_button).not_to be_disabled
    end

    scenario 'submit button disables when required field is cleared' do
      add_work('Generic Work')

      within '#forms-container #resource-form-wrapper-resource-0' do
        fill_in 'resources[resource-0][title][]', with: 'My Work'
        fill_in 'resources[resource-0][creator][]', with: 'Test Creator'
      end

      expect(submit_button).not_to be_disabled

      within '#forms-container #resource-form-wrapper-resource-0' do
        fill_in 'resources[resource-0][title][]', with: ''
      end

      expect(submit_button).to be_disabled
    end

    scenario 'submit button requires ALL forms to be valid' do
      add_collection
      add_work('Generic Work')

      # Fill first form
      within '#forms-container #resource-form-wrapper-resource-0' do
        fill_in 'resources[resource-0][title][]', with: 'My Collection'
        fill_in 'resources[resource-0][creator][]', with: 'Collection Creator'
      end

      # Button still disabled because second form is empty
      expect(submit_button).to be_disabled

      # Fill second form
      within '#forms-container #resource-form-wrapper-resource-1' do
        fill_in 'resources[resource-1][title][]', with: 'My Work'
        fill_in 'resources[resource-1][creator][]', with: 'Test Creator'
      end

      # Now button enables
      expect(submit_button).not_to be_disabled
    end

    scenario 'submit button validates nested works' do
      add_collection

      within '#forms-container #resource-form-wrapper-resource-0' do
        fill_in 'resources[resource-0][title][]', with: 'My Collection'
        fill_in 'resources[resource-0][creator][]', with: 'Collection Creator'
      end

      expect(submit_button).not_to be_disabled

      add_nested_work_to_collection('#resources-list [data-resource-id="resource-0"]', 'Generic Work')

      # Adding nested work disables button
      expect(submit_button).to be_disabled

      # Fill nested work
      within '#forms-container #work-form-wrapper-work-1' do
        fill_in 'resources[resource-0][works][work-1][title][]', with: 'Nested Work'
        fill_in 'resources[resource-0][works][work-1][creator][]', with: 'Test Creator'
      end

      expect(submit_button).not_to be_disabled
    end

    scenario 'submit button validates filesets require file OR remote URL' do
      add_work('Generic Work')

      within '#forms-container #resource-form-wrapper-resource-0' do
        fill_in 'resources[resource-0][title][]', with: 'My Work'
        fill_in 'resources[resource-0][creator][]', with: 'Test Creator'
      end

      expect(submit_button).not_to be_disabled

      add_fileset_to_work('#resources-list [data-resource-id="resource-0"]')

      # Adding fileset disables button (needs title, creator, and file/URL)
      expect(submit_button).to be_disabled

      # Fill in FileSet required fields
      within '#forms-container #fileset-form-wrapper-fileset-1' do
        fill_in 'resources[resource-0][filesets][fileset-1][title][]', with: 'My File'
        fill_in 'resources[resource-0][filesets][fileset-1][creator][]', with: 'File Creator'
        fill_in 'resources[resource-0][filesets][fileset-1][remote_file]',
                with: 'https://example.com/file.jpg'
      end

      expect(submit_button).not_to be_disabled
    end

    scenario 'submit button accepts file upload for fileset' do
      add_work('Generic Work')

      within '#forms-container #resource-form-wrapper-resource-0' do
        fill_in 'resources[resource-0][title][]', with: 'My Work'
        fill_in 'resources[resource-0][creator][]', with: 'Test Creator'
      end

      add_fileset_to_work('#resources-list [data-resource-id="resource-0"]')

      expect(submit_button).to be_disabled

      # Fill in FileSet required fields and attach file
      within '#forms-container #fileset-form-wrapper-fileset-1' do
        fill_in 'resources[resource-0][filesets][fileset-1][title][]', with: 'My File'
        fill_in 'resources[resource-0][filesets][fileset-1][creator][]', with: 'File Creator'
        file_input = find('input[type="file"]', match: :first)
        file_input.attach_file(Skullrax.root.join('spec', 'fixtures', 'files', 'test_file.png'))
      end

      expect(submit_button).not_to be_disabled
    end

    scenario 'submit button re-disables when form is removed' do
      add_collection
      add_work('Generic Work')

      within '#forms-container #resource-form-wrapper-resource-0' do
        fill_in 'resources[resource-0][title][]', with: 'My Collection'
        fill_in 'resources[resource-0][creator][]', with: 'Collection Creator' # ADD THIS
      end

      within '#forms-container #resource-form-wrapper-resource-1' do
        fill_in 'resources[resource-1][title][]', with: 'My Work'
        fill_in 'resources[resource-1][creator][]', with: 'Test Creator'
      end

      expect(submit_button).not_to be_disabled

      # Remove the work
      within '#resources-list [data-resource-id="resource-1"]' do
        find('.remove-resource').click
      end

      # Still enabled because collection is valid
      expect(submit_button).not_to be_disabled

      # Remove collection
      within '#resources-list [data-resource-id="resource-0"]' do
        find('.remove-resource').click
      end

      # Now disabled because no forms
      expect(submit_button).to be_disabled
    end

    scenario 'submit button validates complex hierarchy' do
      add_collection

      within '#forms-container #resource-form-wrapper-resource-0' do
        fill_in 'resources[resource-0][title][]', with: 'My Collection'
        fill_in 'resources[resource-0][creator][]', with: 'Collection Creator'
      end

      expect(submit_button).not_to be_disabled

      add_nested_work_to_collection('#resources-list [data-resource-id="resource-0"]', 'Generic Work')

      expect(submit_button).to be_disabled

      within '#forms-container #work-form-wrapper-work-1' do
        fill_in 'resources[resource-0][works][work-1][title][]', with: 'Nested Work'
        fill_in 'resources[resource-0][works][work-1][creator][]', with: 'Test Creator'
      end

      expect(submit_button).not_to be_disabled

      add_fileset_to_work('.work-item[data-work-id="work-1"]')

      expect(submit_button).to be_disabled

      within '#forms-container #fileset-form-wrapper-fileset-2' do
        fill_in 'resources[resource-0][works][work-1][filesets][fileset-2][title][]', with: 'My File'
        fill_in 'resources[resource-0][works][work-1][filesets][fileset-2][creator][]', with: 'File Creator'
        fill_in 'resources[resource-0][works][work-1][filesets][fileset-2][remote_file]',
                with: 'https://example.com/file.jpg'
      end

      expect(submit_button).not_to be_disabled
    end

    scenario 'submit button handles multi-value fields correctly' do
      add_work('Generic Work')

      within '#forms-container #resource-form-wrapper-resource-0' do
        # Fill required fields
        fill_in 'resources[resource-0][title][]', with: 'My Work'
        fill_in 'resources[resource-0][creator][]', with: 'First Creator'

        # Add another creator
        click_button 'Add another Creator'

        inputs = all('input[name="resources[resource-0][creator][]"]')
        inputs.last.fill_in with: 'Second Creator'
      end

      expect(submit_button).not_to be_disabled
    end

    scenario 'autofill checkbox enables submit button with incomplete forms' do
      add_work('Generic Work')

      # Button disabled because form is empty
      expect(submit_button).to be_disabled

      # Check autofill
      check 'autofill-checkbox'

      # Button now enabled even though form is empty
      expect(submit_button).not_to be_disabled
    end

    scenario 'autofill checkbox bypasses all validation' do
      add_collection
      add_work('Generic Work')

      # Both forms empty, button disabled
      expect(submit_button).to be_disabled

      # Check autofill
      check 'autofill-checkbox'

      # Button enabled with empty forms
      expect(submit_button).not_to be_disabled
    end

    scenario 'unchecking autofill re-enables validation' do
      add_work('Generic Work')

      check 'autofill-checkbox'
      expect(submit_button).not_to be_disabled

      # Uncheck autofill
      uncheck 'autofill-checkbox'

      # Button disabled again because form is empty
      expect(submit_button).to be_disabled
    end

    scenario 'autofill checkbox disables button when no forms exist' do
      # No forms yet
      expect(submit_button).to be_disabled

      check 'autofill-checkbox'

      # Still disabled because there are no forms
      expect(submit_button).to be_disabled

      add_work('Generic Work')

      # Now enabled because there's a form (even if empty)
      expect(submit_button).not_to be_disabled
    end

    scenario 'autofill checkbox with filesets' do
      add_work('Generic Work')
      add_fileset_to_work('#resources-list [data-resource-id="resource-0"]')

      # Button disabled (work and fileset both empty)
      expect(submit_button).to be_disabled

      check 'autofill-checkbox'

      # Button enabled with autofill, even with empty filesets
      expect(submit_button).not_to be_disabled
    end
  end
end
