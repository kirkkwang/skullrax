# frozen_string_literal: true

module Skullrax
  module Mcp
    class Tool
      def self.tool_name
        raise NotImplementedError, "#{name} must implement .tool_name"
      end

      def self.description
        raise NotImplementedError, "#{name} must implement .description"
      end

      def self.input_schema
        raise NotImplementedError, "#{name} must implement .input_schema"
      end

      def self.descriptor
        {
          name: tool_name,
          description:,
          inputSchema: input_schema
        }
      end

      def call(params:, current_user:)
        raise NotImplementedError, "#{self.class.name} must implement #call"
      end

      protected

      def text_response(text)
        { content: [{ type: 'text', text: }] }
      end
    end
  end
end
