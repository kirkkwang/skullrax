# frozen_string_literal: true

RSpec.describe Skullrax::SidebarLinkComponent do
  describe '#render?' do
    let(:component) { described_class.new(menu: double('menu')) }

    it 'is true when the engine routes are mounted' do
      allow(component).to receive(:helpers).and_return(double('helpers', skullrax: nil))

      expect(component.render?).to be true
    end

    it 'is false when the engine routes are not mounted' do
      allow(component).to receive(:helpers).and_return(double('helpers'))

      expect(component.render?).to be false
    end
  end
end
