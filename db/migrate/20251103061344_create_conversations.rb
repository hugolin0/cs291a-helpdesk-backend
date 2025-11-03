class CreateConversations < ActiveRecord::Migration[8.1]
  def change
    create_table :conversations do |t|
      t.string :title, null: false
      t.string :status, null: false, default: 'waiting'
      t.bigint :initiator_id, null: false
      t.bigint :assigned_expert_id
      t.datetime :last_message_at

      t.timestamps
    end
    
    add_foreign_key :conversations, :users, column: :initiator_id
    add_foreign_key :conversations, :users, column: :assigned_expert_id
    add_index :conversations, :initiator_id
    add_index :conversations, :assigned_expert_id
  end
end