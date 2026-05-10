class CreateAgentResults < ActiveRecord::Migration[8.0]
  def change
    create_table :agent_results do |t|
      t.references :review, null: false, foreign_key: true
      t.string  :agent_name,     null: false
      t.string  :priority
      t.text    :findings
      t.text    :files_reviewed,  array: true, default: []
      t.integer :tool_calls_made, default: 0

      t.timestamps
    end
  end
end
