# frozen_string_literal: true

module Notes
  class DestroyService < ::Notes::BaseService
    def execute(note)
      TodoService.new.destroy_target(note, &:destroy)

      clear_noteable_diffs_cache(note)
    end
  end
end
