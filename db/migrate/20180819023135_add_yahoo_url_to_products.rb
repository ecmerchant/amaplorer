class AddYahooUrlToProducts < ActiveRecord::Migration[5.0]
  def change
    add_column :products, :yahoo_url, :string
  end
end
