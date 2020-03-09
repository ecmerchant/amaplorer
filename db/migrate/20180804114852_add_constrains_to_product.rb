class AddConstrainsToProduct < ActiveRecord::Migration[5.0]

  def up
    execute <<-SQL
      ALTER TABLE products
        ADD CONSTRAINT for_upsert UNIQUE ("user", "asin");
    SQL
  end

  def down
    execute <<-SQL
      ALTER TABLE products
        DROP CONSTRAINT for_upsert;
    SQL
  end

end
