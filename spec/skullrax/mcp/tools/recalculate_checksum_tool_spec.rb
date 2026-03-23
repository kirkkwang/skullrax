# frozen_string_literal: true

RSpec.describe Skullrax::Mcp::Tools::RecalculateChecksumTool do
  let(:tool) { described_class.new }
  let(:user) { instance_double(User, email: 'user@example.com') }
  let(:file_set_id) { 'fs-abc123' }
  let(:handler) { instance_double(Skullrax::ChecksumHandler) }

  before do
    allow(Skullrax::ChecksumHandler).to receive(:new).with(file_set_id:).and_return(handler)
  end

  describe '.tool_name' do
    it 'returns recalculate_checksum' do
      expect(described_class.tool_name).to eq('recalculate_checksum')
    end
  end

  describe '.description' do
    it 'mentions MD5 and FileMetadata' do
      expect(described_class.description).to include('MD5', 'FileMetadata')
    end
  end

  describe '.input_schema' do
    it 'requires file_set_id' do
      expect(described_class.input_schema[:required]).to include('file_set_id')
    end

    it 'describes file_set_id as a string' do
      expect(described_class.input_schema[:properties][:file_set_id][:type]).to eq('string')
    end
  end

  describe '#call' do
    context 'when file_set_id is missing' do
      it 'returns an error' do
        result = tool.call(params: {}, current_user: user)
        data = JSON.parse(result[:content].first[:text])

        expect(data['error']).to match(/file_set_id/)
      end
    end

    context 'when the handler returns ok' do
      let(:handler_result) do
        {
          file_set_id:,
          file_metadata_id: 'fm-001',
          filename: 'foo.jpg',
          checksum: 'abc123def456',
          algorithm: 'MD5',
          status: 'ok'
        }
      end

      before { allow(handler).to receive(:recalculate).and_return(handler_result) }

      it 'delegates to ChecksumHandler#recalculate and returns result as JSON' do
        result = tool.call(params: { 'file_set_id' => file_set_id }, current_user: user)
        data = JSON.parse(result[:content].first[:text])

        expect(data['status']).to eq('ok')
        expect(data['checksum']).to eq('abc123def456')
        expect(data['algorithm']).to eq('MD5')
        expect(handler).to have_received(:recalculate)
      end
    end

    context 'when the handler returns an error' do
      let(:handler_result) { { status: 'error', error: 'No OriginalFile found on FileSet fs-abc123' } }

      before { allow(handler).to receive(:recalculate).and_return(handler_result) }

      it 'surfaces the error in the response' do
        result = tool.call(params: { 'file_set_id' => file_set_id }, current_user: user)
        data = JSON.parse(result[:content].first[:text])

        expect(data['status']).to eq('error')
        expect(data['error']).to match(/No OriginalFile found/)
      end
    end
  end
end
