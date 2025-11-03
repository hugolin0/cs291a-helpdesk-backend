class CreateExpertProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :expert_profiles do |t|
      t.bigint :user_id, null: false
      t.text :bio
      t.json :knowledge_base_links

      t.timestamps
    end
    
    add_foreign_key :expert_profiles, :users
    add_index :expert_profiles, :user_id, unique: true
  end
end