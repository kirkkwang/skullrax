# frozen_string_literal: true

RSpec.feature 'Batch Create Interface', js: true do
  before do
    admin = create(:admin)
    login_as(admin, scope: :user)
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

    scenario 'removing a collection with nested works also removes all works and their filesets' do
      add_collection

      add_nested_work_to_collection('#resources-list [data-resource-id="resource-0"]', 'Generic Work')

      add_fileset_to_work('.work-item[data-work-id="work-1"]')

      within '#resources-list [data-resource-id="resource-0"]' do
        find('.remove-resource').click
      end

      expect(page).not_to have_css('.work-item')
      expect(page).not_to have_css('.fileset-item')
      expect(page).not_to have_css('#forms-container [id^="work-form-wrapper-"]')
      expect(page).not_to have_css('#forms-container [id^="fileset-form-wrapper-"]')
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
  end
end
