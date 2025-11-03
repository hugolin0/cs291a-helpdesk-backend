class HealthController < ApplicationController
  def index
    render json: { status: 'ok', timestamp: Time.now.utc.iso8601 }
  end
end
