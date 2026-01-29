# frozen_string_literal: true

require 'generators/skullrax/install_generator'

RSpec.describe Skullrax::InstallGenerator do
  let(:destination) { File.expand_path('../../../tmp/generator_test', __dir__) }

  before do
    FileUtils.rm_rf(destination)
    FileUtils.mkdir_p(File.join(destination, 'config'))
    FileUtils.mkdir_p(File.join(destination, 'config/initializers'))

    File.write(
      File.join(destination, 'config/routes.rb'),
      "Rails.application.routes.draw do\nend\n"
    )

    File.write(
      File.join(destination, 'config/initializers/assets.rb'),
      "# Be sure to restart your server when you modify this file.\n"
    )
  end

  after do
    FileUtils.rm_rf(destination)
  end

  describe 'mounting routes' do
    it 'mounts the Skullrax engine' do
      generator = described_class.new([], {}, { destination_root: destination })
      generator.invoke_all

      routes_content = File.read(File.join(destination, 'config/routes.rb'))
      expect(routes_content).to include("mount Skullrax::Engine => '/skullrax' unless Rails.env.production?")
    end

    it 'skips mounting if already mounted' do
      generator = described_class.new([], {}, { destination_root: destination })
      generator.invoke_all

      generator2 = described_class.new([], {}, { destination_root: destination })

      output = capture(:stdout) { generator2.invoke_all }

      expect(output).to match(/skipped/)
      expect(output).to match(/Skullrax route already mounted/)

      routes_content = File.read(File.join(destination, 'config/routes.rb'))
      expect(routes_content.scan(/mount Skullrax::Engine/).count).to eq(1)
    end
  end

  describe 'adding assets' do
    it 'adds Skullrax assets to precompile list' do
      generator = described_class.new([], {}, { destination_root: destination })
      generator.invoke_all

      assets_content = File.read(File.join(destination, 'config/initializers/assets.rb'))
      expect(assets_content).to include(
        'Rails.application.config.assets.precompile += %w[skullrax/*] unless Rails.env.production?'
      )
    end

    it 'skips adding assets if already added' do
      generator = described_class.new([], {}, { destination_root: destination })
      generator.invoke_all

      generator2 = described_class.new([], {}, { destination_root: destination })

      output = capture(:stdout) { generator2.invoke_all }

      expect(output).to match(/skipped/)
      expect(output).to match(/Skullrax assets already added to precompile list/)

      assets_content = File.read(File.join(destination, 'config/initializers/assets.rb'))
      expect(assets_content.scan(%r{skullrax/\*}).count).to eq(1)
    end

    it 'does not error if assets.rb does not exist' do
      FileUtils.rm(File.join(destination, 'config/initializers/assets.rb'))

      generator = described_class.new([], {}, { destination_root: destination })

      expect { generator.invoke_all }.not_to raise_error
    end
  end
end
