class ExpertAssignment < ApplicationRecord
    belongs_to :conversation
    belongs_to :expert, class_name: 'User'
    
    validates :status, presence: true, inclusion: { in: %w[active unassigned resolved] }
    validates :assigned_at, presence: true
end