# frozen_string_literal: true

RSpec.describe Skullrax::ValkyrieFileSetGenerator do
  before do
    create(:admin, email: 'admin@example.com')
    generator.generate
  end

  let(:file_paths) { Skullrax.root.join('spec', 'fixtures', 'files', 'test_file.png') }
  let(:generator) do
    Skullrax::ValkyrieWorkGenerator.new(file_paths:, file_set_params:)
  end
  let(:work) { generator.resource }
  let(:file_set) { Hyrax.query_service.find_by(id: work.member_ids.first) }

  describe '#update' do
    let(:file_set_params) do
      [{ title: ['Initial File Set'] }]
    end

    it 'updates an existing file set' do
      expect(file_set.title).to eq(['Initial File Set'])
      expect(file_set.subject).to be_empty

      update_generator = Skullrax::ValkyrieFileSetGenerator.new(id: file_set.id, title: ['Updated'], subject: ['Test'])
      update_generator.update
      updated_file_set = Hyrax.query_service.find_by(id: file_set.id)
      expect(updated_file_set.title).to eq(['Updated'])
      expect(updated_file_set.subject).to eq(['Test'])
    end

    it 'will error if the file_set does not exist' do
      generator = described_class.new(id: 'nonexistent-file-set-id', title: 'Updated Title')

      expect { generator.update }.to raise_error(Skullrax::ObjectNotFoundError)
    end

    context 'when using the merge option' do
      it 'merges the new value into the existing one' do
        expect(file_set.title).to eq(['Initial File Set'])

        update_generator = Skullrax::ValkyrieFileSetGenerator.new(id: file_set.id, title: ['With Two Titles'])
        update_generator.update(merge: true)
        updated_file_set = Hyrax.query_service.find_by(id: file_set.id)
        expect(updated_file_set.title).to contain_exactly('Initial File Set', 'With Two Titles')
      end
    end

    context 'when using autofill' do
      it 'fills in all settable properties' do
        expect(file_set.description).to be_empty

        update_generator = described_class.new(id: file_set.id)
        result = update_generator.update(autofill: true)

        expect(result).to be_success
        expect(update_generator.resource.description).to eq ['Test description']
        expect(update_generator.resource.subject).to eq ['Test subject']
      end

      it 'can use the except option to omit properties' do
        expect(file_set.description).to be_empty
        expect(file_set.subject).to be_empty

        update_generator = described_class.new(id: file_set.id)
        result = update_generator.update(autofill: true, except: :subject)

        expect(result).to be_success
        expect(update_generator.resource.description).to eq ['Test description']
        expect(update_generator.resource.subject).to be_empty
      end
    end

    context 'with dry_run' do
      it 'applies updates in memory but does not save them to the database' do
        expect(file_set.subject).to be_empty

        update_generator = described_class.new(id: file_set.id, subject: 'Dry Run Subject')
        result = update_generator.update(dry_run: true)

        expect(result).to be_success

        expect(update_generator.resource.subject).to eq ['Dry Run Subject']

        reloaded_file_set = Hyrax.query_service.find_by(id: file_set.id)
        expect(reloaded_file_set.subject).to be_empty
      end

      it 'still validates the merge logic' do
        expect(file_set.title).to eq(['Initial File Set'])

        update_generator = described_class.new(id: file_set.id, title: ['Another Title'])
        result = update_generator.update(merge: true, dry_run: true)

        expect(result).to be_success
        expect(update_generator.resource.title).to contain_exactly('Initial File Set', 'Another Title')
        reloaded_file_set = Hyrax.query_service.find_by(id: file_set.id)
        expect(reloaded_file_set.title).to eq(['Initial File Set'])
      end
    end
  end

  describe '#destroy' do
    let(:file_set_params) do
      [{ title: ['File Set to be Deleted'] }]
    end

    it 'deletes an existing file set' do
      expect(file_set).to be_persisted

      destroy_generator = Skullrax::ValkyrieFileSetGenerator.new(id: file_set.id)
      result = destroy_generator.destroy

      expect(result).to be_success
      expect { Hyrax.query_service.find_by(id: file_set.id) }.to raise_error(Valkyrie::Persistence::ObjectNotFoundError)

      updated_work = Hyrax.query_service.find_by(id: work.id)
      expect(updated_work.member_ids).not_to include(file_set.id)
    end

    it 'will error if the file set does not exist' do
      generator = described_class.new(id: 'nonexistent-file-set-id')

      expect { generator.destroy }.to raise_error(Skullrax::ObjectNotFoundError)
    end

    context 'with dry_run' do
      it 'validates existence but does not delete the object' do
        expect(file_set).to be_persisted

        destroy_generator = described_class.new(id: file_set.id)
        result = destroy_generator.destroy(dry_run: true)

        expect(result).to be_success

        expect(Hyrax.query_service.find_by(id: file_set.id)).to be_persisted
      end

      it 'still raises error if the object to destroy is missing' do
        destroy_generator = described_class.new(id: 'nonexistent-id')

        expect { destroy_generator.destroy(dry_run: true) }.to raise_error(Skullrax::ObjectNotFoundError)
      end
    end
  end
end
