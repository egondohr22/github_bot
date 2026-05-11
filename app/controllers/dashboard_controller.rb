class DashboardController < ApplicationController
  def index
    installation_ids = current_user.installations.pluck(:id)
    @pull_requests = PullRequest.where(installation_id: installation_ids)
                                .includes(:installation, :reviews)
                                .order(created_at: :desc)
                                .limit(50)
  end
end
