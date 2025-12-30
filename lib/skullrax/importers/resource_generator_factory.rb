# frozen_string_literal: true

module Skullrax
  class ResourceGeneratorFactory
    class << self
      def create(row:, errors:, autofill: false, except: [], **_)
        row.generator_class.new(**row).tap do |generator|
          generator.generate(autofill:, except:)
          add_errors(generator, row.number, errors) if generator.errors.present?
        end
      end

      def update(row:, errors:, merge: false, autofill: false, except: [])
        row.generator_class.new(**row).tap do |generator|
          generator.update(merge:, autofill:, except:)
          add_errors(generator, row.number, errors) if generator.errors.present?
        end
      end

      def destroy(row:, errors:, **_)
        row.generator_class.new(**row).tap do |generator|
          generator.destroy
          add_errors(generator, row.number, errors) if generator.errors.present?
        end
      end

      private

      def add_errors(generator, row_number, errors)
        errors << {
          row_number:,
          resource_type: generator.resource.class,
          errors: generator.errors
        }
      end
    end
  end
end
