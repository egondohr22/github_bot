class CreateInstallations < ActiveRecord::Migration[8.0]
  def change
    create_table :installations do |t|
      t.references :user, null: false, foreign_key: true
      t.string :owner,          null: false
      t.string :repo,           null: false
      t.text   :webhook_secret, null: false

      t.timestamps
    end

    add_index :installations, [:user_id, :repo], unique: true
  end
end
