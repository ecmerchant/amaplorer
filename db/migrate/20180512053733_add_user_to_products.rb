class AddUserToProducts < ActiveRecord::Migration[5.0]
  def change
    add_column :products, :user, :string
  end
  add_index  :products, [:user, :asin], unique: true
end
