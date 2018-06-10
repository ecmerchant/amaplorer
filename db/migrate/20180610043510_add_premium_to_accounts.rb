class AddPremiumToAccounts < ActiveRecord::Migration[5.0]
  def change
    add_column :accounts, :premium, :boolean
    add_column :accounts, :softbank, :boolean
    add_column :accounts, :condition_note, :string
    add_column :accounts, :lead_time, :string
    add_column :accounts, :amazon_point, :float
  end
end
