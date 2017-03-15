class CreateKeyValuesTable < ActiveRecord::Migration
  def self.up
    create_table :key_values do |t|
      t.string :key, :null => false
      t.binary :value, :null => false
      t.datetime :expires_at, :null => true
      t.timestamps :null => false
    end

    add_index :key_values, :key, :unique => true
    add_index :key_values, :expires_at

    change_column :key_values, :id, "bigint(20) NOT NULL AUTO_INCREMENT"
  end

  def self.down
    drop_table :key_values
  end
end
