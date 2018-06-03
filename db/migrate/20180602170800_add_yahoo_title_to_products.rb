class AddYahooTitleToProducts < ActiveRecord::Migration[5.0]
  def change
    add_column :products, :yahoo_title, :string
  end
end
