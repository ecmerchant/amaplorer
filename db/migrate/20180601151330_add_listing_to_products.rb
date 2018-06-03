class AddListingToProducts < ActiveRecord::Migration[5.0]
  def change
    add_column :products, :listing, :boolean
  end
end
