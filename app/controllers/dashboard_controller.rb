class DashboardController < ApplicationController
  def index
    @pull_requests = PullRequest
      .joins(installation: :user)
      .where(installations: { user_id: current_user.id })
      .includes(:reviews, :installation)
      .order(created_at: :desc)
      .limit(50)
  end
end
