class AddFbAfeeToProducts < ActiveRecord::Migration[5.0]
  def change
    add_column :products, :fba_fee, :integer
  end
end
