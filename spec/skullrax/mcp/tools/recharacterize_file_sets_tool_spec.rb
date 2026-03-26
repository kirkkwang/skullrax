# frozen_string_literal: true

RSpec.describe Skullrax::Mcp::Tools::RecharacterizeFileSetsTool do
  let(:tool) { described_class.new }
  let(:user) { instance_double(User, email: 'user@example.com') }
  let(:file_set_id) { 'fs-001' }
  let(:handler) { instance_double(Skullrax::RecharacterizationHandler) }

  describe '.tool_name' do
    it 'returns recharacterize_file_sets' do
      expect(described_class.tool_name).to eq('recharacterize_file_sets')
    end
  end

  describe '.input_schema' do
    it 'requires file_set_id' do
      expect(described_class.input_schema[:required]).to include('file_set_id')
    end

    it 'includes an optional async boolean property' do
      expect(described_class.input_schema[:properties][:async][:type]).to eq('boolean')
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

    context 'with async: true (default)' do
      let(:handler_result) { { file_set_id:, status: 'enqueued', file_metadata_id: 'fm-001' } }

      before do
        allow(Skullrax::RecharacterizationHandler).to receive(:new)
          .with(file_set_id:, async: true)
          .and_return(handler)
        allow(handler).to receive(:call).and_return(handler_result)
      end

      it 'delegates to the handler and returns result as JSON' do
        result = tool.call(params: { 'file_set_id' => file_set_id }, current_user: user)
        data = JSON.parse(result[:content].first[:text])

        expect(data['status']).to eq('enqueued')
        expect(handler).to have_received(:call)
      end
    end

    context 'with async: false' do
      let(:handler_result) { { file_set_id:, status: 'completed', characterization: {} } }

      before do
        allow(Skullrax::RecharacterizationHandler).to receive(:new)
          .with(file_set_id:, async: false)
          .and_return(handler)
        allow(handler).to receive(:call).and_return(handler_result)
      end

      it 'passes async: false to the handler' do
        result = tool.call(
          params: { 'file_set_id' => file_set_id, 'async' => false },
          current_user: user
        )
        data = JSON.parse(result[:content].first[:text])

        expect(data['status']).to eq('completed')
        expect(Skullrax::RecharacterizationHandler).to have_received(:new)
          .with(file_set_id:, async: false)
      end
    end

    context 'when the handler returns an error' do
      let(:handler_result) { { status: 'error', error: 'FileSet not found' } }

      before do
        allow(Skullrax::RecharacterizationHandler).to receive(:new)
          .with(file_set_id:, async: true)
          .and_return(handler)
        allow(handler).to receive(:call).and_return(handler_result)
      end

      it 'surfaces the error in the response' do
        result = tool.call(params: { 'file_set_id' => file_set_id }, current_user: user)
        data = JSON.parse(result[:content].first[:text])

        expect(data['status']).to eq('error')
        expect(data['error']).to eq('FileSet not found')
      end
    end
  end
end
