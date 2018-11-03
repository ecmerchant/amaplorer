class AddAmazonUrlToProducts < ActiveRecord::Migration[5.0]
  def change
    add_column :products, :amazon_url, :string
  end
end
