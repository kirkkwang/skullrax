# frozen_string_literal: true

module BatchCreateHelpers
  def add_collection
    select 'Collection', from: 'resource-type'
  end

  def add_work(type = 'Generic Work')
    select type, from: 'resource-type'
  end

  def add_nested_work_to_collection(collection_selector, work_type = 'Generic Work')
    within collection_selector do
      find('.work-type-select').select(work_type)
    end
  end

  def add_fileset_to_work(work_selector)
    within work_selector do
      click_button 'Add FileSet'
    end
  end
end
