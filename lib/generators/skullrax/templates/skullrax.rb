# frozen_string_literal: true

Skullrax.configure do |config|
  # Global fallback used when generating test values for any model/property.
  # Receives model name and property name as positional arguments (both strings).
  # config.default_test_value = ->(_model, property) { "Test #{property}" }

  # Per-model+property override. Use the model name as a string to avoid load order issues.
  # config.test_default_for('GenericWorkResource', :video_embed) do |_model, _property|
  #   'https://www.youtube.com/embed/Znf73dsFdC8'
  # end

  # Model-level default (no property) — applies to any property on the model not covered
  # by a more specific registration.
  # config.test_default_for('GenericWorkResource') do |model, property|
  #   "Test #{property} for #{model}"
  # end
end
