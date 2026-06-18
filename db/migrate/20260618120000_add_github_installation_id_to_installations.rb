class AddGithubInstallationIdToInstallations < ActiveRecord::Migration[8.0]
  def change
    add_column :installations, :github_installation_id, :bigint
  end
end
