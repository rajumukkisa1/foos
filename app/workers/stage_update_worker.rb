# frozen_string_literal: true

class StageUpdateWorker
  include ApplicationWorker
  include PipelineQueue

  queue_namespace :pipeline_processing

  # rubocop: disable CodeReuse/ActiveRecord
  def perform(stage_id)
    Ci::Stage.find_by(id: stage_id).try(&:update_status)
  end
  # rubocop: enable CodeReuse/ActiveRecord
end
