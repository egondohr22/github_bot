class PullRequestsController < ApplicationController
  def show
    @pull_request = PullRequest.find(params[:id])
    redirect_to dashboard_path, alert: "Not found." unless @pull_request.installation.user_id == current_user.id
  end
end
