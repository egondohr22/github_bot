class CreatePullRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :pull_requests do |t|
      t.references :installation, null: false, foreign_key: true
      t.integer :github_pr_number, null: false
      t.string  :repo,             null: false
      t.string  :head_branch
      t.string  :base_branch
      t.string  :author
      t.string  :status, null: false, default: "pending"

      t.timestamps
    end
  end
end
