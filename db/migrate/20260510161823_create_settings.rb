class CreateSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :settings do |t|
      t.references :user, null: false, foreign_key: true
      t.string :key,   null: false
      t.jsonb  :value, null: false, default: {}

      t.timestamps
    end

    add_index :settings, [:user_id, :key], unique: true
  end
end
