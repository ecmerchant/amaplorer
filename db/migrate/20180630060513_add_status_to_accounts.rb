class AddStatusToAccounts < ActiveRecord::Migration[5.0]
  def change
    add_column :accounts, :asin_status, :string
    add_column :accounts, :amazon_status, :string
    add_column :accounts, :yahoo_status, :string
  end
end
