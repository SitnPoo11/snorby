class CreateSeverities < ActiveRecord::Migration
  def self.up  
    create_table(:severities) do |t|
      t.integer :sig_id
      t.integer :events_count
      t.string :name
      t.string :text_color, :default => '#fff'
      t.string :bg_color, :default => '#ddd'
      
    end
    
    add_index :severities, :sig_id
    add_index :severities, :events_count
    add_index :severities, :text_color
    add_index :severities, :bg_color
    
  end

  def self.down
    drop_table :severities
  end
end
