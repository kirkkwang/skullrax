# frozen_string_literal: true

module Skullrax
  class BasedNearHandler
    class << self
      def handles?(property)
        property == 'based_near'
      end

      def param_key
        'based_near_attributes'
      end

      def default_value
        { '0' => { 'id' => default_geonames_url, '_destroy' => 'false' } }
      end

      def process(values)
        Array.wrap(values).flat_map { |value| lookup_or_return(value) }.compact
      end

      private

      def lookup_or_return(value)
        return value if value.start_with?('http')

        lookup(value)
      end

      def lookup(query)
        response = fetch_geonames(query)
        extract_url(response)
      end

      def fetch_geonames(query)
        uri = build_uri(query)
        Net::HTTP.get_response(uri)
      end

      def build_uri(query)
        URI('http://api.geonames.org/searchJSON').tap do |uri|
          uri.query = URI.encode_www_form(q: query, username:, maxRows: 1)
        end
      end

      def extract_url(response)
        return nil unless response.is_a?(Net::HTTPSuccess)

        geoname_id = parse_geoname_id(response.body)
        geoname_id ? "https://sws.geonames.org/#{geoname_id}/" : nil
      end

      def parse_geoname_id(body)
        JSON.parse(body).dig('geonames', 0, 'geonameId')
      end

      def default_geonames_url
        'https://sws.geonames.org/5391811/'
      end

      def username
        ENV.fetch('GEONAMES_USERNAME', 'scientist')
      end
    end
  end
end
