class CreateProducts < ActiveRecord::Migration[5.0]
  def change
    create_table :products do |t|
      t.string :asin
      t.float :cart_price
      t.float :cart_shipping
      t.integer :cart_point
      t.float :lowest_price
      t.float :lowest_shipping
      t.integer :lowest_point
      t.string :title
      t.string :jan
      t.string :mpn
      t.integer :rank
      t.string :category
      t.string :amazon_image
      t.string :yahoo_code
      t.float :yahoo_price
      t.float :yahoo_shipping
      t.integer :normal_point
      t.integer :premium_point
      t.integer :softbank_point
      t.boolean :isvalid
      t.string :yahoo_image

      t.timestamps
    end
  end
end
