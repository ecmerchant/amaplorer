class AddUniqueIdToAccounts < ActiveRecord::Migration[5.0]
  def change
    add_column :accounts, :unique_id, :string
  end
end
