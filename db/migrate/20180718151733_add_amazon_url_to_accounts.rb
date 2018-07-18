class AddAmazonUrlToAccounts < ActiveRecord::Migration[5.0]
  def change
    add_column :accounts, :amazon_url, :string
  end
end
