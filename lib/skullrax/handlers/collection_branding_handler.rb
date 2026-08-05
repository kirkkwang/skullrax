# frozen_string_literal: true

require 'tmpdir'

module Skullrax
  class CollectionBrandingHandler # rubocop:disable Metrics/ClassLength
    ROLES = %w[banner logo thumbnail].freeze
    KEYS = ROLES.flat_map { |role| [:"#{role}", :"#{role}_alt_text"] }.freeze

    attr_reader :branding, :errors

    def self.extract(kwargs)
      KEYS.index_with { |key| kwargs.delete(key) }.compact
    end

    def initialize(branding:)
      @branding = branding
      @errors = []
    end

    def validate
      Skullrax::FileAttachmentHandler.new(file_paths: sources, user: nil).validate
    end

    def apply(collection)
      ROLES.each do |role|
        source = branding[role.to_sym]
        if source.present?
          apply_role(collection, role, source)
        elsif branding[:"#{role}_alt_text"].present?
          update_alt_text(collection, role)
        end
      end
      errors
    end

    private

    def sources
      ROLES.filter_map { |role| branding[role.to_sym] }
    end

    def apply_role(collection, role, source)
      staged, filename = stage(source)
      generate_thumbnail_derivatives(collection, staged.path, filename) if role == 'thumbnail'
      replace_branding_info(collection, role, staged.path, filename)
    rescue StandardError => e
      errors << I18n.t('skullrax.errors.branding_failed', role:, message: e.message)
    ensure
      staged&.close!
    end

    def stage(source)
      if source.to_s.start_with?('http')
        download(source)
      else
        tempfile = staging_tempfile(File.extname(source))
        FileUtils.cp(source, tempfile.path)
        [tempfile, File.basename(source)]
      end
    end

    def download(url, redirects = 3) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      raise I18n.t('skullrax.errors.remote_file_unreachable', code: 'too many redirects', url:) if redirects.zero?

      uri = URI.parse(url)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
        http.request_get(uri.request_uri)
      end
      if response.is_a?(Net::HTTPRedirection) && response['location']
        return download(URI.join(url, response['location']).to_s, redirects - 1)
      end
      unless response.is_a?(Net::HTTPSuccess)
        raise I18n.t('skullrax.errors.remote_file_unreachable', code: response.code, url:)
      end

      tempfile = staging_tempfile(File.extname(uri.path))
      tempfile.write(response.body)
      tempfile.rewind
      [tempfile, File.basename(uri.path)]
    end

    def staging_tempfile(extension)
      Tempfile.new(['skullrax_branding', extension]).tap(&:binmode)
    end

    def update_alt_text(collection, role)
      record = CollectionBrandingInfo.find_by(collection_id: collection.id.to_s, role:)
      record&.update_column(:alt_text, branding[:"#{role}_alt_text"].to_s)
    end

    def replace_branding_info(collection, role, staged_path, filename) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      stale = CollectionBrandingInfo.where(collection_id: collection.id.to_s, role:).to_a

      info = CollectionBrandingInfo.new(
        collection_id: collection.id.to_s,
        filename:,
        role:,
        alt_txt: branding[:"#{role}_alt_text"].to_s,
        target_url: ''
      )
      info.save(staged_path)

      stale.each do |record|
        record.delete unless record.local_path == info.local_path
      rescue StandardError
        nil
      end
      CollectionBrandingInfo.where(id: stale.map(&:id)).delete_all
    end

    def generate_thumbnail_derivatives(collection, staged_path, filename) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      raise I18n.t('skullrax.errors.thumbnail_unsupported') unless defined?(::UploadedCollectionThumbnailPathService)

      dir = ::UploadedCollectionThumbnailPathService.upload_dir(collection)
      Dir.mktmpdir do |workspace|
        FileUtils.cp(staged_path, File.join(workspace, filename))

        image = MiniMagick::Image.open(staged_path)
        image.format('jpg', 0)
        write_derivatives(image, workspace, collection.id)

        FileUtils.rm_rf(dir)
        FileUtils.mkdir_p(dir)
        FileUtils.cp(Dir[File.join(workspace, '*')], dir)
        Dir[File.join(dir, '*')].each { |file| File.chmod(0o664, file) }
      end
    end

    def write_derivatives(image, dir, collection_id)
      %w[500x900 150x300].zip(%w[card thumbnail]).each do |size, suffix|
        image.resize(size)
        image.write(File.join(dir, "#{collection_id}_#{suffix}.jpg"))
      end
    end
  end
end
