class User < ApplicationRecord
    has_secure_password
    
    has_many :initiated_conversations, class_name: 'Conversation', foreign_key: 'initiator_id'
    has_many :assigned_conversations, class_name: 'Conversation', foreign_key: 'assigned_expert_id'
    has_one :expert_profile, dependent: :destroy
    has_many :messages, foreign_key: 'sender_id'
    has_many :expert_assignments, foreign_key: 'expert_id'
    
    validates :username, presence: true, uniqueness: true
    validates :password_digest, presence: true
end