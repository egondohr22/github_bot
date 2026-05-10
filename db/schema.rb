# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_05_10_161823) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "agent_results", force: :cascade do |t|
    t.bigint "review_id", null: false
    t.string "agent_name", null: false
    t.string "priority"
    t.text "findings"
    t.text "files_reviewed", default: [], array: true
    t.integer "tool_calls_made", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["review_id"], name: "index_agent_results_on_review_id"
  end

  create_table "installations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "owner", null: false
    t.string "repo", null: false
    t.text "webhook_secret", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "repo"], name: "index_installations_on_user_id_and_repo", unique: true
    t.index ["user_id"], name: "index_installations_on_user_id"
  end

  create_table "pull_requests", force: :cascade do |t|
    t.bigint "installation_id", null: false
    t.integer "github_pr_number", null: false
    t.string "repo", null: false
    t.string "head_branch"
    t.string "base_branch"
    t.string "author"
    t.string "status", default: "pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["installation_id"], name: "index_pull_requests_on_installation_id"
  end

  create_table "reviews", force: :cascade do |t|
    t.bigint "pull_request_id", null: false
    t.string "triggered_by_comment"
    t.text "raw_diff"
    t.jsonb "routing_plan"
    t.text "final_comment"
    t.string "status", default: "pending", null: false
    t.datetime "posted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pull_request_id"], name: "index_reviews_on_pull_request_id"
  end

  create_table "settings", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "key", null: false
    t.jsonb "value", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "key"], name: "index_settings_on_user_id_and_key", unique: true
    t.index ["user_id"], name: "index_settings_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "uid", null: false
    t.string "github_username", null: false
    t.string "name"
    t.text "github_token", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["uid"], name: "index_users_on_uid", unique: true
  end

  add_foreign_key "agent_results", "reviews"
  add_foreign_key "installations", "users"
  add_foreign_key "pull_requests", "installations"
  add_foreign_key "reviews", "pull_requests"
  add_foreign_key "settings", "users"
end
