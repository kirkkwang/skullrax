# frozen_string_literal: true

module ControllerHelpers
  def upload_csv(content)
    file = Tempfile.new(['import', '.csv'])
    file.write(content)
    file.rewind
    Rack::Test::UploadedFile.new(file.path, 'text/csv', original_filename: 'import.csv')
  end

  def upload_zip(&block)
    file = Tempfile.new(['import', '.zip'])
    Zip::File.open(file.path, create: true, &block)
    Rack::Test::UploadedFile.new(file.path, 'application/zip', original_filename: 'import.zip')
  end

  def fixture_file(filename)
    Skullrax.root.join('spec/fixtures/files', filename)
  end
end

RSpec.configure do |config|
  config.include ControllerHelpers, type: :request
  config.include BatchCreateHelpers, type: :feature
end
