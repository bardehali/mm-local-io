class CreateIofferTables < ActiveRecord::Migration[6.0]
  def up
    create_table_unless_exists "admins", force: :cascade do |t|
      t.string "email", default: "", null: false
      t.string "encrypted_password", default: "", null: false
      t.string "reset_password_token"
      t.datetime "reset_password_sent_at"
      t.datetime "remember_created_at"
      t.integer "sign_in_count", default: 0, null: false
      t.datetime "current_sign_in_at"
      t.datetime "last_sign_in_at"
      t.string "current_sign_in_ip"
      t.string "last_sign_in_ip"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["email"], name: "index_admins_on_email", unique: true
      t.index ["reset_password_token"], name: "index_admins_on_reset_password_token", unique: true
    end
  
    create_table_unless_exists "brands", force: :cascade do |t|
      t.string "name", limit: 128
      t.string "presentation", limit: 128
      t.integer "position", default: 0
      t.boolean "is_user_created", default: false
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["is_user_created"], name: "index_brands_on_is_user_created"
      t.index ["name"], name: "index_brands_on_name"
    end
  
    create_table_unless_exists "categories", force: :cascade do |t|
      t.string "name", limit: 64, null: false
      t.integer "position", default: 0
      t.integer "lft"
      t.integer "rgt"
      t.integer "depth"
      t.index ["name"], name: "index_categories_on_name"
      t.index ["position"], name: "index_categories_on_position"
    end
  
    create_table_unless_exists "email_subscriptions", force: :cascade do |t|
      t.integer "user_id"
      t.string "email", null: false
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.boolean "is_seller", default: false
      t.boolean "captcha_verified", default: false
      t.string "ip", limit: 60
      t.text "cookies"
      t.string "client_id", limit: 100
      t.index ["email"], name: "index_email_subscriptions_on_email"
      t.index ["ip"], name: "index_email_subscriptions_on_ip"
      t.index ["user_id"], name: "index_email_subscriptions_on_user_id"
    end
  
    create_table_unless_exists "other_site_accounts", force: :cascade do |t|
      t.integer "user_id", null: false
      t.string "site_name", limit: 36, null: false
      t.string "account_id", limit: 64, null: false
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["site_name"], name: "osa_site_name"
      t.index ["user_id"], name: "osa_user_id"
    end
  
    create_table_unless_exists "page_logs", force: :cascade do |t|
      t.string "ip", limit: 80
      t.string "url_path", limit: 360
      t.string "url_params", limit: 240
      t.datetime "last_request_at"
      t.integer "requests_count", default: 0
      t.index ["ip", "url_path"], name: "index_page_logs_on_ip_and_url_path"
    end
  
    create_table_unless_exists "payment_methods", force: :cascade do |t|
      t.string "name"
      t.string "display_name"
      t.integer "position", default: 1
      t.boolean "is_user_created", default: false
      t.index ["is_user_created"], name: "index_payment_methods_on_is_user_created"
      t.index ["name"], name: "index_payment_methods_on_name"
      t.index ["position"], name: "index_payment_methods_on_position"
    end
  
    create_table_unless_exists "user_brands", force: :cascade do |t|
      t.integer "brand_id", null: false
      t.integer "user_id", null: false
      t.index ["user_id"], name: "index_user_brands_on_user_id"
    end
  
    create_table_unless_exists "user_categories", force: :cascade do |t|
      t.integer "user_id", null: false
      t.integer "category_id", null: false
      t.index ["category_id"], name: "index_user_categories_on_category_id"
      t.index ["user_id"], name: "index_user_categories_on_user_id"
    end
  
    create_table_unless_exists "user_payment_methods", force: :cascade do |t|
      t.integer "user_id"
      t.integer "payment_method_id"
      t.index ["user_id"], name: "index_user_payment_methods_on_user_id"
    end
  
    create_table_unless_exists "users", force: :cascade do |t|
      t.string "username", limit: 60
      t.string "encrypted_password", limit: 60
      t.string "email", limit: 120
      t.string "reset_password_token"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.datetime "reset_password_sent_at"
      t.float "rating", default: 0.0
      t.integer "transactions_count", default: 0
      t.integer "items_count", default: 0
      t.string "name", limit: 64
      t.string "location", limit: 64
      t.datetime "member_since"
      t.string "phone", limit: 32
      t.text "address"
      t.integer "positive", default: 0
      t.integer "negative", default: 0
      t.decimal "gms", precision: 13, scale: 2, default: "0.0"
      t.datetime "last_visit_at"
      t.string "visit_from_source", limit: 128
      t.datetime "last_email_at"
      t.text "session"
      t.string "ip", limit: 64
      t.integer "email_trial_count", default: 0
      t.text "cookies"
      t.string "client_id", limit: 100
      t.string "auto_login_token", limit: 200
      t.string "user_group_names", limit: 240
      t.string "pin_code", limit: 16
      t.datetime "pin_code_verified_at"
      t.index ["auto_login_token"], name: "index_users_on_auto_login_token"
      t.index ["email"], name: "index_users_on_email"
      t.index ["last_email_at"], name: "index_users_on_last_email_at"
      t.index ["user_group_names"], name: "index_users_on_user_group_names"
      t.index ["username"], name: "index_users_on_username"
    end
  end

  def down
    %w(admins brands categories email_subscriptions other_site_accounts page_logs payment_methods user_brands user_categories user_payment_methods users).each do|table_name|
      drop_table_if_exists table_name
    end
  end
end
