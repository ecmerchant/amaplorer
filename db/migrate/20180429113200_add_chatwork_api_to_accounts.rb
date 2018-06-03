class AddChatworkApiToAccounts < ActiveRecord::Migration[5.0]
  def change
    add_column :accounts, :cw_api_token, :string
    add_column :accounts, :cw_room_id, :string
  end
end
