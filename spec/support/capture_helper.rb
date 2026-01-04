# frozen_string_literal: true

module CaptureHelper
  def capture(stream)
    original = stream == :stdout ? $stdout : $stderr
    captured = StringIO.new
    stream == :stdout ? $stdout = captured : $stderr = captured
    yield
    captured.string
  ensure
    stream == :stdout ? $stdout = original : $stderr = original
  end
end

RSpec.configure do |config|
  config.include CaptureHelper
end
