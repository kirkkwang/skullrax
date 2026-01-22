# frozen_string_literal: true

RSpec.feature 'Export Resources Interface', js: true do
  include Devise::Test::IntegrationHelpers

  let(:admin) { create(:admin, email: 'admin@example.com') }
  let(:file1) { Skullrax.root.join('spec', 'fixtures', 'files', 'test_file.png') }
  let(:file2) { Skullrax.root.join('spec', 'fixtures', 'files', 'test_file.txt') }

  let!(:work_id1) do
    Skullrax::ValkyrieWorkGenerator.new(
      file_paths: [file1],
      user: admin
    ).generate(autofill: true).value!.id.to_s
  end
  let!(:work_id2) do
    Skullrax::ValkyrieWorkGenerator.new(
      file_paths: [file2],
      user: admin
    ).generate(autofill: true).value!.id.to_s
  end

  before do
    sign_in admin
    visit skullrax.root_path
  end

  describe 'export button enabling' do
    scenario 'export button enables when IDs are entered' do
      export_button = find('#export-link')
      textarea = find('#export_ids')

      expect(export_button[:class]).to include('disabled')

      textarea.fill_in with: work_id1

      expect(export_button[:class]).not_to include('disabled')
      expect(export_button[:style]).not_to include('pointer-events: none')
    end

    scenario 'export button disables when textarea is cleared' do
      export_button = find('#export-link')
      textarea = find('#export_ids')

      textarea.fill_in with: work_id1
      expect(export_button[:class]).not_to include('disabled')

      textarea.fill_in with: ''
      expect(export_button[:class]).to include('disabled')
    end

    scenario 'export button enables with multiple IDs on separate lines' do
      export_button = find('#export-link')
      textarea = find('#export_ids')

      textarea.fill_in with: "#{work_id1}\n#{work_id2}"

      expect(export_button[:class]).not_to include('disabled')
    end

    scenario 'export button enables with whitespace around IDs' do
      export_button = find('#export-link')
      textarea = find('#export_ids')

      textarea.fill_in with: "  #{work_id1}  \n  #{work_id2}  "

      expect(export_button[:class]).not_to include('disabled')
    end
  end

  describe 'successful export' do
    scenario 'export button is clickable with valid IDs' do
      textarea = find('#export_ids')
      export_button = find('#export-link')

      textarea.fill_in with: work_id1

      expect(export_button[:class]).not_to include('disabled')
      expect { export_button.click }.not_to raise_error

      # Should stay on the same page (download happens in background)
      expect(current_path).to eq(skullrax.root_path)
    end
  end

  describe 'error handling' do
    scenario 'submitting with empty IDs shows error message' do
      # Manually trigger navigation with empty IDs to test server-side validation
      visit "#{skullrax.exports_path}?ids=&include_files=0"

      expect(page).to have_css('.alert', text: /enter at least one ID/i)
    end

    scenario 'submitting with only whitespace shows error message' do
      visit "#{skullrax.exports_path}?ids=#{CGI.escape("  \n  \n  ")}&include_files=0"

      expect(page).to have_css('.alert', text: /enter at least one ID/)
    end

    scenario 'submitting with non-existent ID shows error message' do
      textarea = find('#export_ids')
      export_button = find('#export-link')

      textarea.fill_in with: 'non-existent-id'
      export_button.click

      expect(page).to have_css('.alert', text: /ID not found: non-existent-id/)
    end

    scenario 'submitting with multiple non-existent IDs shows all missing IDs' do
      textarea = find('#export_ids')
      export_button = find('#export-link')

      textarea.fill_in with: "fake-id-1\nfake-id-2"
      export_button.click

      expect(page).to have_css('.alert', text: /2 IDs not found: fake-id-1, fake-id-2/)
    end

    scenario 'submitting with mix of valid and invalid IDs shows only invalid ones' do
      textarea = find('#export_ids')
      export_button = find('#export-link')

      textarea.fill_in with: "#{work_id1}\nfake-id"
      export_button.click

      expect(page).to have_css('.alert', text: /ID not found: fake-id/)
    end
  end

  describe 'textarea formatting' do
    scenario 'accepts IDs with various line break formats' do
      export_button = find('#export-link')
      textarea = find('#export_ids')

      # Test with different line break styles
      textarea.fill_in with: "#{work_id1}\r\n#{work_id2}"

      expect(export_button[:class]).not_to include('disabled')
    end
  end
end
