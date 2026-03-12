# frozen_string_literal: true

RSpec.describe Skullrax::BatchCreate::CardComponent do
  subject(:component) { described_class.new }

  describe '#work_options' do
    context 'when Hyku is defined' do
      before do
        stub_const('Hyku', Module.new)
        stub_const('Site', Class.new { def self.instance; end })
        allow(Site).to receive(:instance).and_return(
          double(available_works: %w[Monograph GenericWorkResource])
        )
      end

      it 'uses Site.instance.available_works' do
        html = component.work_options

        expect(html).to include('Monograph')
        expect(html).to include('Generic Work Resource')
      end
    end

    context 'when Hyku is not defined' do
      before do
        allow(Hyrax.config).to receive(:registered_curation_concern_types)
          .and_return(['GenericWorkResource'])
      end

      it 'uses Hyrax.config.registered_curation_concern_types' do
        html = component.work_options

        expect(html).to include('Generic Work Resource')
      end
    end
  end
end
