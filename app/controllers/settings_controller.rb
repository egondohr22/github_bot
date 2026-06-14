class SettingsController < ApplicationController
  def show
    @review_settings = current_user.review_settings
  end

  def update
    Setting.set(current_user, ReviewSettings::KEY, review_params)
    redirect_to settings_path, notice: "Settings saved."
  end

  private

  def review_params
    {
      "max_tool_calls"   => params[:max_tool_calls].to_i,
      "enabled_agents"   => Array(params[:enabled_agents]).select { |a| ReviewSettings.available_agents.include?(a) },
      "agent_priorities" => agent_priorities_param
    }
  end

  def agent_priorities_param
    submitted = params[:agent_priorities]
    return {} unless submitted.respond_to?(:to_unsafe_h)

    submitted.to_unsafe_h.slice(*ReviewSettings.available_agents).select do |_agent, level|
      ReviewSettings::PRIORITY_LEVELS.include?(level.to_s)
    end
  end
end
