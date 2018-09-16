class CreateMessengers < ActiveRecord::Migration[5.0]
  def change
    create_table :messengers do |t|
      t.string :user
      t.text :comment

      t.timestamps
    end
  end
end
