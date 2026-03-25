# frozen_string_literal: true

RSpec.describe Skullrax::Mcp::Tools::DeleteResourcesTool do
  let(:tool) { described_class.new }
  let(:user) { instance_double(User, email: 'user@example.com') }

  let(:success_result) { double('result', success?: true) }
  let(:failure_result) { double('result', success?: false) }
  let(:generator) { instance_double(Skullrax::ValkyrieWorkGenerator, destroy: success_result, errors: []) }
  let(:failing_generator) do
    instance_double(Skullrax::ValkyrieWorkGenerator, destroy: failure_result, errors: ['Not found'])
  end
  let(:work_resource) { instance_double(GenericWorkResource) }

  # Stub child file set lookup to return nothing by default for work deletions
  before do
    allow(Hyrax.query_service).to receive(:find_by).with(id: 'abc123').and_return(work_resource)
    allow(Hyrax.custom_queries).to receive(:find_child_file_sets)
      .with(resource: work_resource).and_return([])
  end

  describe '.tool_name' do
    it 'returns delete_resources' do
      expect(described_class.tool_name).to eq('delete_resources')
    end
  end

  describe '.input_schema' do
    it 'requires resource_type, ids, and confirm' do
      schema = described_class.input_schema

      expect(schema[:required]).to include('resource_type', 'ids', 'confirm')
    end
  end

  describe '#call' do
    context 'when confirm is false' do
      it 'returns an error without deleting' do
        allow(Skullrax::ValkyrieWorkGenerator).to receive(:new)

        result = tool.call(
          params: { 'resource_type' => 'work', 'ids' => ['abc123'], 'confirm' => false },
          current_user: user
        )
        data = JSON.parse(result[:content].first[:text])

        expect(data['error']).to match(/not confirmed/i)
        expect(Skullrax::ValkyrieWorkGenerator).not_to have_received(:new)
      end
    end

    context 'when confirm is omitted' do
      it 'returns an error without deleting' do
        result = tool.call(
          params: { 'resource_type' => 'work', 'ids' => ['abc123'] },
          current_user: user
        )
        data = JSON.parse(result[:content].first[:text])

        expect(data['error']).to match(/not confirmed/i)
      end
    end

    context 'when deleting works' do
      before do
        allow(Skullrax::ValkyrieWorkGenerator).to receive(:new).and_return(generator)
      end

      it 'deletes the work and returns deleted status' do
        result = tool.call(
          params: { 'resource_type' => 'work', 'ids' => ['abc123'], 'confirm' => true },
          current_user: user
        )
        data = JSON.parse(result[:content].first[:text])

        expect(data.first['status']).to eq('deleted')
        expect(data.first['id']).to eq('abc123')
      end

      it 'passes id and user to the generator' do
        tool.call(
          params: { 'resource_type' => 'work', 'ids' => ['abc123'], 'confirm' => true },
          current_user: user
        )

        expect(Skullrax::ValkyrieWorkGenerator).to have_received(:new)
          .with(hash_including(id: 'abc123', user:))
      end
    end

    context 'when deleting a work that has child file sets' do
      let(:fs_id_a) { instance_double(Valkyrie::ID, to_s: 'fs-001') }
      let(:fs_id_b) { instance_double(Valkyrie::ID, to_s: 'fs-002') }
      let(:file_set_a) { instance_double(Hyrax::FileSet, id: fs_id_a) }
      let(:file_set_b) { instance_double(Hyrax::FileSet, id: fs_id_b) }
      let(:fs_generator) { instance_double(Skullrax::ValkyrieFileSetGenerator, destroy: success_result, errors: []) }

      before do
        allow(Skullrax::ValkyrieWorkGenerator).to receive(:new).and_return(generator)
        allow(Hyrax.custom_queries).to receive(:find_child_file_sets)
          .with(resource: work_resource).and_return([file_set_a, file_set_b])
        allow(Skullrax::ValkyrieFileSetGenerator).to receive(:new).and_return(fs_generator)
      end

      it 'destroys each child file set before destroying the work' do
        tool.call(
          params: { 'resource_type' => 'work', 'ids' => ['abc123'], 'confirm' => true },
          current_user: user
        )

        expect(Skullrax::ValkyrieFileSetGenerator).to have_received(:new)
          .with(hash_including(id: 'fs-001', user:))
        expect(Skullrax::ValkyrieFileSetGenerator).to have_received(:new)
          .with(hash_including(id: 'fs-002', user:))
        expect(fs_generator).to have_received(:destroy).twice
      end

      it 'still reports the work as deleted' do
        result = tool.call(
          params: { 'resource_type' => 'work', 'ids' => ['abc123'], 'confirm' => true },
          current_user: user
        )
        data = JSON.parse(result[:content].first[:text])

        expect(data.first['status']).to eq('deleted')
      end
    end

    context 'when deleting collections' do
      let(:col_generator) do
        instance_double(Skullrax::ValkyrieCollectionGenerator, destroy: success_result, errors: [])
      end

      before do
        allow(Skullrax::ValkyrieCollectionGenerator).to receive(:new).and_return(col_generator)
      end

      it 'dispatches to ValkyrieCollectionGenerator' do
        result = tool.call(
          params: { 'resource_type' => 'collection', 'ids' => ['col456'], 'confirm' => true },
          current_user: user
        )
        data = JSON.parse(result[:content].first[:text])

        expect(Skullrax::ValkyrieCollectionGenerator).to have_received(:new)
        expect(data.first['status']).to eq('deleted')
      end
    end

    context 'when deleting file sets' do
      let(:fs_generator) do
        instance_double(Skullrax::ValkyrieFileSetGenerator, destroy: success_result, errors: [])
      end

      before do
        allow(Skullrax::ValkyrieFileSetGenerator).to receive(:new).and_return(fs_generator)
      end

      it 'dispatches to ValkyrieFileSetGenerator' do
        result = tool.call(
          params: { 'resource_type' => 'file_set', 'ids' => ['fs789'], 'confirm' => true },
          current_user: user
        )
        data = JSON.parse(result[:content].first[:text])

        expect(Skullrax::ValkyrieFileSetGenerator).to have_received(:new)
        expect(data.first['status']).to eq('deleted')
      end
    end

    context 'when an exception is raised during delete' do
      before do
        allow(Skullrax::ValkyrieWorkGenerator).to receive(:new).and_raise(StandardError, 'Something went wrong')
      end

      it 'returns failed status with error message' do
        result = tool.call(
          params: { 'resource_type' => 'work', 'ids' => ['abc123'], 'confirm' => true },
          current_user: user
        )
        data = JSON.parse(result[:content].first[:text])

        expect(data.first['status']).to eq('failed')
        expect(data.first['errors']).to include('Something went wrong')
      end
    end

    context 'when delete fails' do
      before do
        allow(Skullrax::ValkyrieWorkGenerator).to receive(:new).and_return(failing_generator)
      end

      it 'returns failed status with errors' do
        result = tool.call(
          params: { 'resource_type' => 'work', 'ids' => ['abc123'], 'confirm' => true },
          current_user: user
        )
        data = JSON.parse(result[:content].first[:text])

        expect(data.first['status']).to eq('failed')
        expect(data.first['errors']).to include('Not found')
      end
    end

    context 'when deleting multiple IDs' do
      let(:work_resource_b) { instance_double(GenericWorkResource) }

      before do
        allow(Skullrax::ValkyrieWorkGenerator).to receive(:new).and_return(generator)
        allow(Hyrax.query_service).to receive(:find_by).with(id: 'def456').and_return(work_resource_b)
        allow(Hyrax.custom_queries).to receive(:find_child_file_sets)
          .with(resource: work_resource_b).and_return([])
      end

      it 'deletes each resource and returns results for all' do
        result = tool.call(
          params: { 'resource_type' => 'work', 'ids' => %w[abc123 def456], 'confirm' => true },
          current_user: user
        )
        data = JSON.parse(result[:content].first[:text])

        expect(data.length).to eq(2)
        expect(data.all? { |r| r['status'] == 'deleted' }).to be true
      end
    end
  end
end
