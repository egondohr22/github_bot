class InstallationsController < ApplicationController
  before_action :set_installation, only: [:show, :destroy]

  def index
    @installations = current_user.installations.order(created_at: :desc)
  end

  def new
    @installation = current_user.installations.build
    @repos = cached_repos
  end

  def create
    @installation = current_user.installations.build(installation_params)
    @installation.owner ||= @installation.repo.to_s.split("/").first
    if @installation.save
      redirect_to @installation, notice: "Repo added successfully."
    else
      @repos = cached_repos
      render :new, status: :unprocessable_entity
    end
  end

  def show; end

  def destroy
    @installation.destroy
    redirect_to installations_path, notice: "Repo removed."
  end

  private

  def set_installation
    @installation = current_user.installations.find(params[:id])
  end

  def cached_repos
    Rails.cache.fetch("github_repos/#{current_user.id}", expires_in: 5.minutes) do
      GithubService.new(token: current_user.github_token).list_repos
    end
  end

  def installation_params
    params.require(:installation).permit(:owner, :repo)
  end
end
