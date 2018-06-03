class AddUniqueIdToProducts < ActiveRecord::Migration[5.0]
  def change
    add_column :products, :unique_id, :string
  end
end
