class AddUserLevelToAccounts < ActiveRecord::Migration[5.0]
  def change
    add_column :accounts, :user_level, :string
  end
end
