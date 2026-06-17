class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def github
    @user = User.from_omniauth(request.env["omniauth.auth"])
    if @user.persisted?
      sign_in_and_redirect @user, event: :authentication
    else
      redirect_to root_path, alert: "GitHub authentication failed."
    end
  end

  def failure
    redirect_to root_path, alert: "Authentication failed."
  end

  private

  def after_sign_in_path_for(_user)
    dashboard_path
  end
end
