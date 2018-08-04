class AddUserToProducts < ActiveRecord::Migration[5.0]
  def change
    add_column :products, :user, :string
  end
end
