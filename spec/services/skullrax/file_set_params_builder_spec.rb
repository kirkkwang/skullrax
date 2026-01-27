# frozen_string_literal: true

RSpec.describe Skullrax::FileSetParamsBuilder do
  let(:user) { create(:user) }
  let(:file1) { Skullrax.root.join('spec', 'fixtures', 'files', 'test_file.png') }
  let(:file2) { Skullrax.root.join('spec', 'fixtures', 'files', 'test_file.txt') }
  let(:file_paths) { [file1, file2] }
  let(:file_set_params) do
    [
      { title: ['Title 1'], visibility: ['open'] },
      { title: ['Title 2'], visibility: ['restricted'] }
    ]
  end

  describe '#formatted_file_set_params' do
    it 'includes uploaded_file_id in each params hash' do
      builder = described_class.new(file_paths:, file_set_params:, user:)
      uploaded_ids = builder.uploaded_file_ids
      formatted = builder.formatted_file_set_params

      expect(formatted.size).to eq(2)
      expect(uploaded_ids.size).to eq(2)

      formatted.each_with_index do |params, index|
        expect(params[:uploaded_file_id]).to eq(uploaded_ids[index].to_s)
      end
    end
  end
end
