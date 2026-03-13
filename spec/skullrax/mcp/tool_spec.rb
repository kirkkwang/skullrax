# frozen_string_literal: true

RSpec.describe Skullrax::Mcp::Tool do
  describe '.tool_name' do
    it 'raises NotImplementedError on the base class' do
      expect { described_class.tool_name }.to raise_error(NotImplementedError)
    end
  end

  describe '.description' do
    it 'raises NotImplementedError on the base class' do
      expect { described_class.description }.to raise_error(NotImplementedError)
    end
  end

  describe '.input_schema' do
    it 'raises NotImplementedError on the base class' do
      expect { described_class.input_schema }.to raise_error(NotImplementedError)
    end
  end

  describe '.descriptor' do
    let(:tool_class) do
      Class.new(described_class) do
        def self.tool_name = 'my_tool'
        def self.description = 'Does something useful'
        def self.input_schema = { type: 'object', properties: {} }
      end
    end

    it 'returns a hash with name, description, and inputSchema' do
      descriptor = tool_class.descriptor

      expect(descriptor[:name]).to eq('my_tool')
      expect(descriptor[:description]).to eq('Does something useful')
      expect(descriptor[:inputSchema]).to eq({ type: 'object', properties: {} })
    end
  end

  describe '#call' do
    it 'raises NotImplementedError on the base class' do
      expect { described_class.new.call(params: {}, current_user: nil) }.to raise_error(NotImplementedError)
    end
  end

  describe '#text_response' do
    let(:tool_class) do
      Class.new(described_class) do
        def self.tool_name = 'test'
        def self.description = 'test'
        def self.input_schema = {}

        def call(**)
          text_response('hello')
        end
      end
    end

    it 'wraps text in MCP content format' do
      result = tool_class.new.call(params: {}, current_user: nil)

      expect(result).to eq({ content: [{ type: 'text', text: 'hello' }] })
    end
  end
end
