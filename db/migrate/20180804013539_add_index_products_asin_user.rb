class AddIndexProductsAsinUser < ActiveRecord::Migration[5.0]
  def change
      add_index  :products, [:user, :asin], unique: true
  end
end
