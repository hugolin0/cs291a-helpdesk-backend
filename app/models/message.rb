class Message < ApplicationRecord
    belongs_to :conversation
    belongs_to :sender, class_name: 'User'
    
    validates :content, presence: true
    validates :sender_role, presence: true, inclusion: { in: %w[initiator expert] }
end