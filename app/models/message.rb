class Message < ApplicationRecord
    belongs_to :conversation, touch: true
    belongs_to :sender, class_name: 'User'
    
    validates :content, presence: true
    validates :sender_role, presence: true, inclusion: { in: %w[initiator expert] }
end