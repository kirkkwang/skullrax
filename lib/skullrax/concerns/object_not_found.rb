# frozen_string_literal: true

module Skullrax
  module ObjectNotFound
    def object_not_found_errors
      [Valkyrie::Persistence::ObjectNotFoundError]
    end
  end
end
