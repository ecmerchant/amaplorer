# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20180804114852) do

  create_table "accounts", force: :cascade do |t|
    t.string   "user"
    t.string   "seller_id"
    t.string   "mws_auth_token"
    t.datetime "created_at",     null: false
    t.datetime "updated_at",     null: false
    t.string   "user_level"
    t.string   "cw_api_token"
    t.string   "cw_room_id"
    t.string   "unique_id"
    t.boolean  "premium"
    t.boolean  "softbank"
    t.string   "condition_note"
    t.string   "lead_time"
    t.float    "amazon_point"
    t.string   "asin_status"
    t.string   "amazon_status"
    t.string   "yahoo_status"
    t.string   "amazon_url"
  end

  create_table "products", force: :cascade do |t|
    t.string   "asin"
    t.float    "cart_price"
    t.float    "cart_shipping"
    t.integer  "cart_point"
    t.float    "lowest_price"
    t.float    "lowest_shipping"
    t.integer  "lowest_point"
    t.string   "title"
    t.string   "jan"
    t.string   "mpn"
    t.integer  "rank"
    t.string   "category"
    t.string   "amazon_image"
    t.string   "yahoo_code"
    t.float    "yahoo_price"
    t.float    "yahoo_shipping"
    t.integer  "normal_point"
    t.integer  "premium_point"
    t.integer  "softbank_point"
    t.boolean  "isvalid"
    t.string   "yahoo_image"
    t.datetime "created_at",      null: false
    t.datetime "updated_at",      null: false
    t.string   "user"
    t.string   "unique_id"
    t.boolean  "listing"
    t.string   "yahoo_title"
    t.float    "amazon_fee"
    t.integer  "profit"
    t.integer  "listing_count"
    t.integer  "fba_fee"
    t.index ["user", "asin"], name: "index_products_on_user_and_asin", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string   "email",                  default: "", null: false
    t.string   "encrypted_password",     default: "", null: false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          default: 0,  null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.datetime "created_at",                          null: false
    t.datetime "updated_at",                          null: false
    t.boolean  "admin_flg"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

end
