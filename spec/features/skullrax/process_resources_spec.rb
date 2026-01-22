# frozen_string_literal: true

RSpec.feature 'Process Resources Interface', js: true do
  include Devise::Test::IntegrationHelpers

  let(:admin) { create(:admin, email: 'admin@example.com') }

  before do
    sign_in admin
    visit skullrax.root_path
  end

  describe 'submit button validation' do
    scenario 'submit button enables when file is selected' do
      submit_button = find('#import-submit')
      file_input = find('input[type="file"]#import_file')

      expect(submit_button).to be_disabled
      file_input.attach_file(Skullrax.root.join('spec', 'fixtures', 'files', 'test_file.png'))
      expect(submit_button).not_to be_disabled

      find('input[type="radio"][value="update"]').click
      expect(submit_button).not_to be_disabled
    end
  end

  describe 'form submission with create action' do
    let(:csv_content) do
      <<~CSV
        title,creator,visibility
        Test Title 1,Author One,open
      CSV
    end

    scenario 'successful submission shows success message' do
      file_input = find('input[type="file"]#import_file')
      submit_button = find('#import-submit')

      # Create a temporary CSV file
      csv_file = Tempfile.new(['import', '.csv'])
      csv_file.write(csv_content)
      csv_file.rewind

      file_input.attach_file(csv_file.path)
      submit_button.click

      expect(page).to have_css('.alert-success', text: /Import completed successfully/)

      csv_file.close
      csv_file.unlink
    end
  end

  describe 'form submission with update action' do
    let!(:existing_work) do
      generator = Skullrax::ValkyrieWorkGenerator.new(
        id: 'existing-work-1',
        title: 'Old Title',
        creator: 'Old Author'
      )
      generator.generate
      generator.resource
    end

    let(:csv_content) do
      <<~CSV
        id,title,creator
        existing-work-1,New Title,New Author
      CSV
    end

    scenario 'successful update shows success message' do
      update_radio = find('input[type="radio"][value="update"]')
      file_input = find('input[type="file"]#import_file')
      submit_button = find('#import-submit')

      update_radio.click

      csv_file = Tempfile.new(['update', '.csv'])
      csv_file.write(csv_content)
      csv_file.rewind

      file_input.attach_file(csv_file.path)
      submit_button.click

      expect(page).to have_css('.alert-success', text: /Import completed successfully/)

      csv_file.close
      csv_file.unlink
    end

    scenario 'updating non-existent resource shows error message' do
      update_radio = find('input[type="radio"][value="update"]')
      file_input = find('input[type="file"]#import_file')
      submit_button = find('#import-submit')

      update_radio.click

      csv_content = <<~CSV
        id,title,creator
        non-existent-work,Title,Author
      CSV

      csv_file = Tempfile.new(['update_error', '.csv'])
      csv_file.write(csv_content)
      csv_file.rewind

      file_input.attach_file(csv_file.path)
      submit_button.click

      expect(page).to have_css('.alert', text: /Import failed/)
      expect(page).to have_css('.alert', text: /ID not found: non-existent-work/)

      csv_file.close
      csv_file.unlink
    end
  end

  describe 'form submission with destroy action' do
    let!(:existing_work) do
      generator = Skullrax::ValkyrieWorkGenerator.new(
        id: 'work-to-delete',
        title: 'To Be Deleted',
        creator: 'Author'
      )
      generator.generate
      generator.resource
    end

    let(:csv_content) do
      <<~CSV
        id
        work-to-delete
      CSV
    end

    scenario 'successful destroy shows success message' do
      destroy_radio = find('input[type="radio"][value="destroy"]')
      file_input = find('input[type="file"]#import_file')
      submit_button = find('#import-submit')

      destroy_radio.click

      csv_file = Tempfile.new(['destroy', '.csv'])
      csv_file.write(csv_content)
      csv_file.rewind

      file_input.attach_file(csv_file.path)
      submit_button.click

      expect(page).to have_css('.alert-success', text: /Import completed successfully/)

      csv_file.close
      csv_file.unlink
    end

    scenario 'destroying non-existent resource shows error message' do
      destroy_radio = find('input[type="radio"][value="destroy"]')
      file_input = find('input[type="file"]#import_file')
      submit_button = find('#import-submit')

      destroy_radio.click

      csv_content = <<~CSV
        id
        non-existent-work
      CSV

      csv_file = Tempfile.new(['destroy_error', '.csv'])
      csv_file.write(csv_content)
      csv_file.rewind

      file_input.attach_file(csv_file.path)
      submit_button.click

      expect(page).to have_css('.alert', text: /Import failed/)
      expect(page).to have_css('.alert', text: /ID not found: non-existent-work/)

      csv_file.close
      csv_file.unlink
    end
  end

  describe 'error handling' do
    scenario 'malformed CSV shows error message' do
      file_input = find('input[type="file"]#import_file')
      submit_button = find('#import-submit')

      csv_content = <<~CSV
        title,creator,description
        malformed work,Some Author,12'-6" clearance
      CSV

      csv_file = Tempfile.new(['malformed', '.csv'])
      csv_file.write(csv_content)
      csv_file.rewind

      file_input.attach_file(csv_file.path)
      submit_button.click

      expect(page).to have_css('.alert', text: /Import failed/)
      expect(page).to have_css('.alert', text: /Malformed CSV/)

      csv_file.close
      csv_file.unlink
    end
  end
end
