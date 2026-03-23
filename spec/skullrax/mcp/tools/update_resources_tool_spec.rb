# frozen_string_literal: true

RSpec.describe Skullrax::Mcp::Tools::UpdateResourcesTool do
  let(:tool) { described_class.new }
  let(:user) { instance_double(User, email: 'user@example.com') }

  let(:work_resource) { double('resource', id: double('id', to_s: 'abc123')) }
  let(:success_result) { double('result', success?: true, value!: work_resource) }
  let(:failure_result) { double('result', success?: false) }
  let(:generator) { instance_double(Skullrax::ValkyrieWorkGenerator, update: success_result, errors: []) }
  let(:failing_generator) do
    instance_double(Skullrax::ValkyrieWorkGenerator, update: failure_result, errors: ['Creator is required'])
  end

  describe '.tool_name' do
    it 'returns update_resources' do
      expect(described_class.tool_name).to eq('update_resources')
    end
  end

  describe '.input_schema' do
    it 'requires resource_type and records' do
      schema = described_class.input_schema

      expect(schema[:required]).to include('resource_type', 'records')
    end
  end

  describe '#call' do
    let(:record) { { 'id' => 'abc123', 'title' => ['Updated Title'] } }

    context 'when updating works' do
      before do
        allow(Skullrax::ValkyrieWorkGenerator).to receive(:new).and_return(generator)
      end

      it 'updates the work and returns updated status' do
        result = tool.call(
          params: { 'resource_type' => 'work', 'records' => [record] },
          current_user: user
        )
        data = JSON.parse(result[:content].first[:text])

        expect(data.first['status']).to eq('updated')
        expect(data.first['id']).to eq('abc123')
      end

      it 'passes id and attrs to the generator' do
        tool.call(
          params: { 'resource_type' => 'work', 'records' => [record] },
          current_user: user
        )

        expect(Skullrax::ValkyrieWorkGenerator).to have_received(:new)
          .with(hash_including(id: 'abc123', user:))
      end
    end

    context 'when updating collections' do
      let(:col_resource) { double('collection', id: double('id', to_s: 'col456')) }
      let(:col_success) { double('result', success?: true, value!: col_resource) }
      let(:col_generator) { instance_double(Skullrax::ValkyrieCollectionGenerator, update: col_success, errors: []) }
      let(:col_record) { { 'id' => 'col456', 'title' => ['Updated Collection'] } }

      before do
        allow(Skullrax::ValkyrieCollectionGenerator).to receive(:new).and_return(col_generator)
      end

      it 'dispatches to ValkyrieCollectionGenerator' do
        result = tool.call(
          params: { 'resource_type' => 'collection', 'records' => [col_record] },
          current_user: user
        )
        data = JSON.parse(result[:content].first[:text])

        expect(Skullrax::ValkyrieCollectionGenerator).to have_received(:new)
        expect(data.first['status']).to eq('updated')
      end
    end

    context 'when updating file sets' do
      let(:fs_resource) { double('file_set', id: double('id', to_s: 'fs789')) }
      let(:fs_success) { double('result', success?: true, value!: fs_resource) }
      let(:fs_generator) { instance_double(Skullrax::ValkyrieFileSetGenerator, update: fs_success, errors: []) }
      let(:fs_record) { { 'id' => 'fs789', 'title' => ['Updated File'] } }

      before do
        allow(Skullrax::ValkyrieFileSetGenerator).to receive(:new).and_return(fs_generator)
      end

      it 'dispatches to ValkyrieFileSetGenerator' do
        result = tool.call(
          params: { 'resource_type' => 'file_set', 'records' => [fs_record] },
          current_user: user
        )
        data = JSON.parse(result[:content].first[:text])

        expect(Skullrax::ValkyrieFileSetGenerator).to have_received(:new)
        expect(data.first['status']).to eq('updated')
      end
    end

    context 'when an exception is raised during update' do
      before do
        allow(Skullrax::ValkyrieWorkGenerator).to receive(:new).and_raise(StandardError, 'Something went wrong')
      end

      it 'returns failed status with error message' do
        result = tool.call(
          params: { 'resource_type' => 'work', 'records' => [record] },
          current_user: user
        )
        data = JSON.parse(result[:content].first[:text])

        expect(data.first['status']).to eq('failed')
        expect(data.first['errors']).to include('Something went wrong')
      end
    end

    context 'when update fails' do
      before do
        allow(Skullrax::ValkyrieWorkGenerator).to receive(:new).and_return(failing_generator)
      end

      it 'returns failed status with errors' do
        result = tool.call(
          params: { 'resource_type' => 'work', 'records' => [record] },
          current_user: user
        )
        data = JSON.parse(result[:content].first[:text])

        expect(data.first['status']).to eq('failed')
        expect(data.first['errors']).to include('Creator is required')
      end
    end

    context 'when defaults are provided' do
      let(:defaults) { { 'visibility' => 'open', 'publisher' => ['Default Publisher'] } }
      let(:record) { { 'id' => 'abc123', 'title' => ['Updated Title'] } }

      before do
        allow(Skullrax::ValkyrieWorkGenerator).to receive(:new).and_return(generator)
      end

      it 'merges defaults into each record' do
        tool.call(
          params: { 'resource_type' => 'work', 'defaults' => defaults, 'records' => [record] },
          current_user: user
        )

        expect(Skullrax::ValkyrieWorkGenerator).to have_received(:new)
          .with(hash_including(visibility: 'open', publisher: ['Default Publisher'], title: ['Updated Title']))
      end

      it 'allows record-level values to override defaults' do
        overriding_record = { 'id' => 'abc123', 'title' => ['Updated Title'], 'publisher' => ['Override Publisher'] }

        tool.call(
          params: { 'resource_type' => 'work', 'defaults' => defaults, 'records' => [overriding_record] },
          current_user: user
        )

        expect(Skullrax::ValkyrieWorkGenerator).to have_received(:new)
          .with(hash_including(publisher: ['Override Publisher']))
      end

      it 'applies defaults to every record in the batch' do
        tool.call(
          params: { 'resource_type' => 'work', 'defaults' => defaults, 'records' => [record, record] },
          current_user: user
        )

        expect(Skullrax::ValkyrieWorkGenerator).to have_received(:new)
          .with(hash_including(visibility: 'open')).twice
      end
    end
  end
end
