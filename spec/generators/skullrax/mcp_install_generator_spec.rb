# frozen_string_literal: true

require 'generators/skullrax/mcp_install_generator'

RSpec.describe Skullrax::McpInstallGenerator do
  let(:destination) { File.expand_path('../../../tmp/mcp_generator_test', __dir__) }
  let(:initializer_path) { File.join(destination, 'config/initializers/skullrax.rb') }
  let(:routes_path) { File.join(destination, 'config/routes.rb') }

  let(:initializer_with_mcp_commented_out) do
    <<~RUBY
      # frozen_string_literal: true

      Skullrax.configure do |config|
        # config.mcp_enabled = true
      end
    RUBY
  end

  let(:bare_routes) do
    <<~RUBY
      Rails.application.routes.draw do
        devise_for :users
      end
    RUBY
  end

  before do
    FileUtils.rm_rf(destination)
    FileUtils.mkdir_p(File.join(destination, 'config/initializers'))
    FileUtils.mkdir_p(File.join(destination, 'db/migrate'))
    File.write(routes_path, bare_routes)
  end

  after do
    FileUtils.rm_rf(destination)
  end

  describe 'enabling MCP in initializer' do
    context 'when the skullrax initializer exists with the commented-out flag' do
      before { File.write(initializer_path, initializer_with_mcp_commented_out) }

      it 'uncomments config.mcp_enabled = true' do
        generator = described_class.new([], {}, { destination_root: destination })
        allow(generator).to receive(:generate)
        generator.invoke_all

        expect(File.read(initializer_path)).to include('config.mcp_enabled = true')
        expect(File.read(initializer_path)).not_to include('# config.mcp_enabled = true')
      end

      it 'skips if mcp_enabled is already uncommented' do
        enabled_content = initializer_with_mcp_commented_out.gsub('# config.mcp_enabled', 'config.mcp_enabled')
        File.write(initializer_path, enabled_content)

        generator = described_class.new([], {}, { destination_root: destination })
        allow(generator).to receive(:generate)
        output = capture(:stdout) { generator.invoke_all }

        expect(output).to match(/skipped/)
        expect(output).to match(/MCP already enabled/)
      end
    end

    context 'when no skullrax initializer exists' do
      it 'creates the initializer with mcp_enabled = true' do
        generator = described_class.new([], {}, { destination_root: destination })
        allow(generator).to receive(:generate)
        generator.invoke_all

        expect(File.exist?(initializer_path)).to be true
        expect(File.read(initializer_path)).to include('config.mcp_enabled = true')
      end
    end
  end

  describe 'installing Doorkeeper' do
    before { File.write(initializer_path, initializer_with_mcp_commented_out) }

    it 'runs doorkeeper:install and doorkeeper:migration generators' do
      generator = described_class.new([], {}, { destination_root: destination })
      allow(generator).to receive(:generate)

      generator.invoke_all

      expect(generator).to have_received(:generate).with('doorkeeper:install')
      expect(generator).to have_received(:generate).with('doorkeeper:migration')
    end

    it 'skips if Doorkeeper migration already exists' do
      FileUtils.touch(File.join(destination, 'db/migrate/20240101000000_create_doorkeeper_tables.rb'))

      generator = described_class.new([], {}, { destination_root: destination })
      allow(generator).to receive(:generate)

      output = capture(:stdout) { generator.invoke_all }

      expect(generator).not_to have_received(:generate).with('doorkeeper:install')
      expect(output).to match(/skipped/)
      expect(output).to match(/Doorkeeper migration already exists/)
    end
  end

  describe 'configuring Doorkeeper initializer' do
    let(:doorkeeper_init_path) { File.join(destination, 'config/initializers/doorkeeper.rb') }
    let(:doorkeeper_boilerplate) do
      <<~RUBY
        Doorkeeper.configure do
          orm :active_record

          resource_owner_authenticator do
            raise "Please configure doorkeeper resource_owner_authenticator block located in \#{__FILE__}"
          end
        end
      RUBY
    end

    before { File.write(initializer_path, initializer_with_mcp_commented_out) }

    it 'patches resource_owner_authenticator to use Devise' do
      File.write(doorkeeper_init_path, doorkeeper_boilerplate)

      generator = described_class.new([], {}, { destination_root: destination })
      allow(generator).to receive(:generate)
      generator.invoke_all

      content = File.read(doorkeeper_init_path)
      expect(content).to include('current_user || warden.authenticate!')
      expect(content).not_to include('raise "Please configure')
    end

    it 'adds optional_scopes for MCP' do
      File.write(doorkeeper_init_path, doorkeeper_boilerplate)

      generator = described_class.new([], {}, { destination_root: destination })
      allow(generator).to receive(:generate)
      generator.invoke_all

      expect(File.read(doorkeeper_init_path)).to include('optional_scopes :mcp, :openid, :email, :profile')
    end

    it 'skips if doorkeeper initializer does not exist' do
      generator = described_class.new([], {}, { destination_root: destination })
      allow(generator).to receive(:generate)
      output = capture(:stdout) { generator.invoke_all }

      expect(output).to match(/skipped/)
      expect(output).to match(/doorkeeper\.rb not found/)
    end

    it 'skips if already configured for Skullrax' do
      File.write(doorkeeper_init_path,
                 "Doorkeeper.configure do\n  resource_owner_authenticator do\n" \
                 "    current_user || warden.authenticate!(scope: :user)\n  end\nend\n")

      generator = described_class.new([], {}, { destination_root: destination })
      allow(generator).to receive(:generate)
      output = capture(:stdout) { generator.invoke_all }

      expect(output).to match(/skipped/)
      expect(output).to match(/already configured for Skullrax/)
    end
  end

  describe 'injecting use_doorkeeper into routes' do
    before { File.write(initializer_path, initializer_with_mcp_commented_out) }

    it 'injects use_doorkeeper into config/routes.rb' do
      generator = described_class.new([], {}, { destination_root: destination })
      allow(generator).to receive(:generate)
      generator.invoke_all

      expect(File.read(routes_path)).to include('use_doorkeeper')
    end

    it 'skips if use_doorkeeper already present' do
      File.write(routes_path, "Rails.application.routes.draw do\n  use_doorkeeper\nend\n")

      generator = described_class.new([], {}, { destination_root: destination })
      allow(generator).to receive(:generate)
      output = capture(:stdout) { generator.invoke_all }

      expect(output).to match(/skipped/)
      expect(output).to match(/use_doorkeeper already in routes/)
    end
  end
end
