# frozen_string_literal: true

require 'generators/skullrax/install_generator'

RSpec.describe Skullrax::InstallGenerator do
  let(:destination) { File.expand_path('../../../tmp/generator_test', __dir__) }

  before do
    FileUtils.rm_rf(destination)
    FileUtils.mkdir_p(File.join(destination, 'config'))
    File.write(
      File.join(destination, 'config/routes.rb'),
      "Rails.application.routes.draw do\nend\n"
    )
  end

  after do
    FileUtils.rm_rf(destination)
  end

  it 'mounts the Skullrax engine' do
    generator = described_class.new([], {}, { destination_root: destination })
    generator.invoke_all

    routes_content = File.read(File.join(destination, 'config/routes.rb'))
    expect(routes_content).to include("mount Skullrax::Engine => '/skullrax'")
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
