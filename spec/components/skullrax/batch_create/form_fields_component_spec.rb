# frozen_string_literal: true

RSpec.describe Skullrax::BatchCreate::FormFieldsComponent do
  describe '#render_field' do
    let(:resource) { GenericWorkResource.new }
    let(:form) { Hyrax::Forms::ResourceForm.for(resource:) }
    let(:form_builder) { SimpleForm::FormBuilder.new(form.model_name.param_key, form, nil, {}) }

    context 'when term is a regular field' do
      it 'renders the edit field partial' do
        component = described_class.new(form:, form_builder:)
        expect(component).to receive(:render_edit_field_partial).with(
          :title,
          f: form_builder,
          curation_concern: form.model_class
        )
        component.render_field(:title)
      end
    end
  end
end
