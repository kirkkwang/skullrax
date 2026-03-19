# frozen_string_literal: true

module Skullrax
  module Mcp
    class Tool
      class << self
        def tool_name
          raise NotImplementedError, "#{name} must implement .tool_name"
        end

        def description
          raise NotImplementedError, "#{name} must implement .description"
        end

        def input_schema
          raise NotImplementedError, "#{name} must implement .input_schema"
        end

        def descriptor
          {
            name: tool_name,
            description:,
            inputSchema: input_schema
          }
        end
      end

      def call(params:, current_user:)
        raise NotImplementedError, "#{self.class.name} must implement #call"
      end

      def solr_rows
        1_000
      end

      protected

      def text_response(text)
        { content: [{ type: 'text', text: }] }
      end
    end
  end
end
