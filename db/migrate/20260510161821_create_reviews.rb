class CreateReviews < ActiveRecord::Migration[8.0]
  def change
    create_table :reviews do |t|
      t.references :pull_request, null: false, foreign_key: true
      t.string  :triggered_by_comment
      t.text    :raw_diff
      t.jsonb   :routing_plan
      t.text    :final_comment
      t.string  :status, null: false, default: "pending"
      t.datetime :posted_at

      t.timestamps
    end
  end
end
