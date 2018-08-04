class AddConstrainsToProduct < ActiveRecord::Migration[5.0]
  def change
    if Rails.env.production? then
      sql = 'ALTER TABLE products ADD CONSTRAINT for_upsert UNIQUE ("user", asin);'
      ActiveRecord::Base.connection.execute(sql)
    end 
  end
end
