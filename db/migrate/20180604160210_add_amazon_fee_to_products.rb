class AddAmazonFeeToProducts < ActiveRecord::Migration[5.0]
  def change
    add_column :products, :amazon_fee, :float
  end
end
