class AddProfitToProducts < ActiveRecord::Migration[5.0]
  def change
    add_column :products, :profit, :integer
    add_column :products, :listing_count, :integer
  end
end
