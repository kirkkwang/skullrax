# frozen_string_literal: true

module Skullrax
  class ResourceProcessor
    def initialize(action:, errors:, merge:, autofill:, except:)
      @action = action
      @errors = errors
      @merge = merge
      @autofill = autofill
      @except = except
    end

    def generate_resource(row:)
      ResourceGeneratorFactory.public_send(action, row:, errors:, merge:, autofill:, except:)
    end

    private

    attr_reader :action, :errors, :merge, :autofill, :except
  end
end
