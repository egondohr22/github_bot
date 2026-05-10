class SettingsController < ApplicationController
  def show
    @settings = current_user.settings.index_by(&:key)
  end

  def update
    Setting.set(current_user, params[:key], params[:value])
    redirect_to settings_path, notice: "Settings saved."
  end
end
