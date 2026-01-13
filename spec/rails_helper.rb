# frozen_string_literal: true

# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
ENV['RAILS_ENV'] = 'test'
require '/app/samvera/hyrax-webapp/config/environment' # require hyrax environment
# Prevent database truncation if the environment is production
abort('The Rails environment is running in production mode!') if Rails.env.production?
require 'rspec/rails'
# Add additional requires below this line. Rails is not loaded until this point!

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
# Rails.root.glob('spec/support/**/*.rb').sort_by(&:to_s).each { |f| require f }

require 'database_cleaner/active_record'
require 'factory_bot'
require 'webmock/rspec'
require 'capybara/rspec'
require 'selenium-webdriver'

Capybara.register_driver :selenium_chrome_headless do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless=new')
  options.add_argument('--disable-gpu')
  options.add_argument('--window-size=1400,1400')
  options.add_argument('--disable-dev-shm-usage')

  driver = Capybara::Selenium::Driver.new(
    app,
    browser: :remote,
    url: ENV.fetch('SE_DRIVER_URL', 'http://chrome:4444/wd/hub'),
    options:
  )

  driver.browser.file_detector = lambda do |args|
    str = args.first.to_s
    str if File.exist?(str)
  end

  driver
end

Capybara.javascript_driver = :selenium_chrome_headless

WebMock.disable_net_connect!(
  allow_localhost: true,
  allow: [
    'fcrepo:8080',
    'solr:8983',
    'redis:6379',
    'postgres:5432',
    'chrome:4444'
  ]
)

require Hyrax::Engine.root.join('lib', 'hyrax', 'specs', 'shared_specs', 'factories', 'strategies',
                                'valkyrie_resource').to_s
require Hyrax::Engine.root.join('lib', 'hyrax', 'specs', 'shared_specs', 'factories', 'administrative_sets').to_s
require Hyrax::Engine.root.join('lib', 'hyrax', 'specs', 'shared_specs', 'factories', 'permission_templates').to_s
require Hyrax::Engine.root.join('lib', 'hyrax', 'specs', 'shared_specs', 'factories',
                                'permission_template_accesses').to_s
require Hyrax::Engine.root.join('lib', 'hyrax', 'specs', 'shared_specs', 'factories', 'users').to_s
require Hyrax::Engine.root.join('spec', 'support', 'fakes', 'test_hydra_group_service').to_s

FactoryBot.register_strategy(:valkyrie_create, ValkyrieCreateStrategy)

Dir[File.expand_path('support/**/*.rb', __dir__)].sort.each { |f| require f }

# Checks for pending migrations and applies them before tests are run.
# If you are not using ActiveRecord, you can remove these lines.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end
RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = Rails.root.join('spec/fixtures')

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # You can uncomment this line to turn off ActiveRecord support entirely.
  # config.use_active_record = false

  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  #
  # You can disable this behaviour by removing the line below, and instead
  # explicitly tag your specs with their type, e.g.:
  #
  #     RSpec.describe UsersController, type: :controller do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://rspec.info/features/6-0/rspec-rails
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")

  config.include FactoryBot::Syntax::Methods
  config.before(:suite) do
    DatabaseCleaner.allow_remote_database_url = true
    DatabaseCleaner.clean_with(:truncation)
    User.group_service = TestHydraGroupService.new
  end

  config.before(:each) do
    Blacklight.default_index.connection.delete_by_query('*:*')
    Blacklight.default_index.connection.commit
  end

  config.include ActiveJob::TestHelper

  config.before(:each, type: :feature, js: true) do
    # Force the test server to listen on all interfaces (0.0.0.0) so the external 'chrome' container can reach it.
    Capybara.server_host = '0.0.0.0'

    # Use a fixed port (3001) to prevent race conditions and ensure we know where to point Chrome.
    Capybara.server_port = 3001

    # Tell Chrome: "When I say visit '/', go to http://web:3001"
    # 'web' is the name of the web service in docker-compose.yml
    Capybara.app_host = "http://web:#{Capybara.server_port}"
  end

  config.include Warden::Test::Helpers

  config.after(:each, type: :feature) do
    Warden.test_reset!
  end

  config.before(:each) do
    # Kept getting test failures because of external HTTP calls made during tests so sticking this here.
    # This handles the 'autofill: true' behavior in generators
    stub_request(:get, 'http://www.geonames.org/getJSON?geonameId=5391811&username=')
      .with(
        headers: {
          'Accept' => 'application/json',
          'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'User-Agent' => 'Faraday v2.14.0'
        }
      )
      .to_return(
        status: 200,
        body: '{"name": "San Diego", "geonameId": 5391811, "countryCode": "US"}',
        headers: { 'Content-Type' => 'application/json' }
      )
  end
end
