# frozen_string_literal: true

RSpec.describe Skullrax::CollectionBrandingHandler do
  let(:collection) { double('collection', id: 'col-123') }
  let(:image_file) { Tempfile.new(['branding', '.jpg']).tap { |f| f.write('fake image bytes') && f.rewind } }
  let(:image_path) { image_file.path }

  describe '.extract' do
    it 'removes branding keys from kwargs and returns them' do
      kwargs = { title: ['T'], banner: '/tmp/b.jpg', banner_alt_text: 'A banner', thumbnail: '/tmp/t.jpg' }

      branding = described_class.extract(kwargs)

      expect(branding).to eq(banner: '/tmp/b.jpg', banner_alt_text: 'A banner', thumbnail: '/tmp/t.jpg')
      expect(kwargs).to eq(title: ['T'])
    end

    it 'returns an empty hash when no branding keys are present' do
      kwargs = { title: ['T'] }

      expect(described_class.extract(kwargs)).to eq({})
      expect(kwargs).to eq(title: ['T'])
    end
  end

  describe '#validate' do
    it 'delegates source paths to FileAttachmentHandler' do
      handler = described_class.new(branding: { banner: '/nope/missing.jpg', banner_alt_text: 'x' })

      file_handler = instance_double(Skullrax::FileAttachmentHandler, validate: ['not found'])
      expect(Skullrax::FileAttachmentHandler)
        .to receive(:new).with(file_paths: ['/nope/missing.jpg'], user: nil).and_return(file_handler)

      expect(handler.validate).to eq(['not found'])
    end
  end

  describe '#apply' do
    let(:branding_info) { double('branding_info', save: true, local_path: 'col-123/banner/new.jpg') }

    it 'replaces the banner branding info row only after the new one saves' do
      handler = described_class.new(branding: { banner: image_path, banner_alt_text: 'My banner' })

      stale_record = double('stale_record', id: 7, local_path: 'col-123/banner/old.jpg')
      stale_relation = double('stale')
      expect(CollectionBrandingInfo).to receive(:where)
        .with(collection_id: 'col-123', role: 'banner').and_return(double('relation', to_a: [stale_record]))
      expect(CollectionBrandingInfo).to receive(:new)
        .with(hash_including(collection_id: 'col-123', role: 'banner', alt_txt: 'My banner'))
        .and_return(branding_info)
      expect(branding_info).to receive(:save).ordered
      expect(stale_record).to receive(:delete).ordered
      expect(CollectionBrandingInfo).to receive(:where).with(id: [7]).ordered.and_return(stale_relation)
      expect(stale_relation).to receive(:delete_all).ordered

      expect(handler.apply(collection)).to be_empty
    end

    it 'updates alt text in place when only the alt text kwarg is given' do
      handler = described_class.new(branding: { banner_alt_text: 'Just new alt text' })

      record = double('record')
      expect(CollectionBrandingInfo).to receive(:find_by)
        .with(collection_id: 'col-123', role: 'banner').and_return(record)
      expect(record).to receive(:update_column).with(:alt_text, 'Just new alt text')

      expect(handler.apply(collection)).to be_empty
    end

    it 'records an error for thumbnails outside Hyku' do
      hide_const('UploadedCollectionThumbnailPathService')
      handler = described_class.new(branding: { thumbnail: image_path })

      errors = handler.apply(collection)

      expect(errors.first).to include('thumbnail')
    end

    it 'writes card and thumbnail derivatives through MiniMagick in Hyku' do
      upload_dir = Dir.mktmpdir
      service = double('service', upload_dir:)
      stub_const('UploadedCollectionThumbnailPathService', service)

      image = double('image')
      allow(MiniMagick::Image).to receive(:open).and_return(image)
      expect(image).to receive(:format).with('jpg', 0)
      allow(image).to receive(:resize)
      expect(image).to receive(:write).twice do |target|
        FileUtils.touch(target)
      end

      relation = double('relation', to_a: [], delete_all: 0)
      allow(CollectionBrandingInfo).to receive(:where).and_return(relation)
      allow(CollectionBrandingInfo).to receive(:new).and_return(branding_info)

      handler = described_class.new(branding: { thumbnail: image_path, thumbnail_alt_text: 'Thumb' })

      expect(handler.apply(collection)).to be_empty
      expect(File.exist?(File.join(upload_dir, 'col-123_card.jpg'))).to be true
      expect(File.exist?(File.join(upload_dir, 'col-123_thumbnail.jpg'))).to be true
    end
  end
end
