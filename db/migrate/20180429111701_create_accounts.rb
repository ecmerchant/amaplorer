class CreateAccounts < ActiveRecord::Migration[5.0]
  def change
    create_table :accounts do |t|
      t.string :user
      t.string :seller_id
      t.string :mws_auth_token

      t.timestamps
    end
  end
end
