class ReviewsController < ApplicationController
  def show
    @review = Review.find(params[:id])
    redirect_to dashboard_path, alert: "Not found." unless @review.pull_request.installation.user_id == current_user.id
  end
end
