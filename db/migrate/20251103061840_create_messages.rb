class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages do |t|
      t.bigint :conversation_id, null: false
      t.bigint :sender_id, null: false
      t.string :sender_role, null: false
      t.text :content, null: false
      t.boolean :is_read, null: false, default: false

      t.timestamps
    end
    
    add_foreign_key :messages, :conversations
    add_foreign_key :messages, :users, column: :sender_id
    add_index :messages, :conversation_id
    add_index :messages, :sender_id
  end
end