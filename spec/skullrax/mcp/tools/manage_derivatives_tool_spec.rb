# frozen_string_literal: true

RSpec.describe Skullrax::Mcp::Tools::ManageDerivativesTool do
  let(:tool) { described_class.new }
  let(:user) { instance_double(User, email: 'user@example.com') }
  let(:file_set_id) { 'fs-001' }
  let(:manager) { instance_double(Skullrax::DerivativesHandler) }

  before do
    allow(Skullrax::DerivativesHandler).to receive(:new).with(file_set_id).and_return(manager)
  end

  describe '.tool_name' do
    it 'returns manage_derivatives' do
      expect(described_class.tool_name).to eq('manage_derivatives')
    end
  end

  describe '.input_schema' do
    it 'requires file_set_id and mode' do
      expect(described_class.input_schema[:required]).to include('file_set_id', 'mode')
    end

    it 'enumerates the four modes' do
      mode_enum = described_class.input_schema[:properties][:mode][:enum]

      expect(mode_enum).to match_array(%w[list regenerate create delete])
    end

    it 'accepts a freeform string for derivative_type' do
      props = described_class.input_schema[:properties][:derivative_type]

      expect(props[:type]).to eq('string')
      expect(props).not_to have_key(:enum)
    end

    it 'describes derivative_type as an ImageMagick-writable format name' do
      description = described_class.input_schema[:properties][:derivative_type][:description]

      expect(description).to include('ImageMagick-writable format name')
    end
  end

  describe '#call' do
    context 'when file_set_id is missing' do
      it 'returns an error' do
        result = tool.call(params: { 'mode' => 'list' }, current_user: user)
        data = JSON.parse(result[:content].first[:text])

        expect(data['error']).to match(/file_set_id/)
      end
    end

    context 'when mode is missing' do
      it 'returns an error' do
        result = tool.call(params: { 'file_set_id' => file_set_id }, current_user: user)
        data = JSON.parse(result[:content].first[:text])

        expect(data['error']).to match(/mode/)
      end
    end

    context 'with mode: list' do
      let(:list_result) do
        {
          file_set_id:,
          mime_type: 'image/jpeg',
          existing_derivatives: [],
          available_menu_items: %w[thumbnail jp2],
          imagemagick_writable_formats: %w[JPEG PNG]
        }
      end

      before { allow(manager).to receive(:list).and_return(list_result) }

      it 'delegates to DerivativesHandler#list and returns result as JSON' do
        result = tool.call(
          params: { 'file_set_id' => file_set_id, 'mode' => 'list' },
          current_user: user
        )
        data = JSON.parse(result[:content].first[:text])

        expect(data['file_set_id']).to eq(file_set_id)
        expect(data['mime_type']).to eq('image/jpeg')
        expect(data['available_menu_items']).to include('thumbnail', 'jp2')
      end
    end

    context 'with mode: regenerate' do
      let(:regenerate_result) { { file_set_id:, status: 'enqueued', message: 'Cleanup complete.' } }

      before { allow(manager).to receive(:regenerate).and_return(regenerate_result) }

      it 'delegates to DerivativesHandler#regenerate' do
        result = tool.call(
          params: { 'file_set_id' => file_set_id, 'mode' => 'regenerate' },
          current_user: user
        )
        data = JSON.parse(result[:content].first[:text])

        expect(data['status']).to eq('enqueued')
        expect(manager).to have_received(:regenerate)
      end
    end

    context 'with mode: create' do
      let(:create_result) { { file_set_id:, derivative_type: 'jp2', status: 'enqueued' } }

      before { allow(manager).to receive(:create).with('jp2', 'image/jp2').and_return(create_result) }

      it 'delegates to DerivativesHandler#create with derivative_type and mime_type' do
        result = tool.call(
          params: { 'file_set_id' => file_set_id, 'mode' => 'create',
                    'derivative_type' => 'jp2', 'mime_type' => 'image/jp2' },
          current_user: user
        )
        data = JSON.parse(result[:content].first[:text])

        expect(data['status']).to eq('enqueued')
        expect(data['derivative_type']).to eq('jp2')
      end

      context 'when derivative_type is missing' do
        it 'returns an error without calling the manager' do
          result = tool.call(
            params: { 'file_set_id' => file_set_id, 'mode' => 'create', 'mime_type' => 'image/jp2' },
            current_user: user
          )
          data = JSON.parse(result[:content].first[:text])

          expect(data['error']).to match(/derivative_type/)
          expect(manager).not_to have_received(:create)
        end
      end

      context 'when mime_type is missing' do
        it 'returns an error without calling the manager' do
          result = tool.call(
            params: { 'file_set_id' => file_set_id, 'mode' => 'create', 'derivative_type' => 'jp2' },
            current_user: user
          )
          data = JSON.parse(result[:content].first[:text])

          expect(data['error']).to match(/mime_type/)
          expect(manager).not_to have_received(:create)
        end
      end
    end

    context 'with mode: delete' do
      let(:delete_result) do
        { file_set_id:, file_id: 'thumb-001', status: 'deleted',
          filename: '97-thumbnail.jpeg', pcdm_use: 'ThumbnailImage', mime_type: 'image/jpeg' }
      end

      before { allow(manager).to receive(:delete).with('thumb-001').and_return(delete_result) }

      it 'delegates to DerivativesHandler#delete with the file_id' do
        result = tool.call(
          params: { 'file_set_id' => file_set_id, 'mode' => 'delete', 'file_id' => 'thumb-001' },
          current_user: user
        )
        data = JSON.parse(result[:content].first[:text])

        expect(data['status']).to eq('deleted')
        expect(data['pcdm_use']).to eq('ThumbnailImage')
      end

      context 'when file_id is missing' do
        it 'returns an error without calling the manager' do
          result = tool.call(
            params: { 'file_set_id' => file_set_id, 'mode' => 'delete' },
            current_user: user
          )
          data = JSON.parse(result[:content].first[:text])

          expect(data['error']).to match(/file_id/)
          expect(manager).not_to have_received(:delete)
        end
      end
    end

    context 'when mode is unrecognized' do
      it 'returns an error' do
        result = tool.call(
          params: { 'file_set_id' => file_set_id, 'mode' => 'explode' },
          current_user: user
        )
        data = JSON.parse(result[:content].first[:text])

        expect(data['error']).to match(/Unknown mode/)
      end
    end

    context 'when the manager raises Skullrax::ArgumentError' do
      before { allow(manager).to receive(:list).and_raise(Skullrax::ArgumentError, 'FileSet not found: fs-001') }

      it 'returns the error message as JSON' do
        result = tool.call(
          params: { 'file_set_id' => file_set_id, 'mode' => 'list' },
          current_user: user
        )
        data = JSON.parse(result[:content].first[:text])

        expect(data['error']).to eq('FileSet not found: fs-001')
      end
    end
  end
end
