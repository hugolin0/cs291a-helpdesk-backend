class ExpertController < ApplicationController
  before_action :authorize_jwt!
  before_action :set_conversation, only: [:claim, :unclaim]
  before_action :set_expert_profile, only: [:get_profile, :update_profile]

  # GET /expert/queue
  def queue
    waiting_conversations = Conversation.where(status: 'waiting')
                                        .includes(:initiator, :assigned_expert, :messages)
                                        .order(created_at: :asc)
                                        
    assigned_conversations = current_user_jwt.assigned_conversations
                                             .includes(:initiator, :assigned_expert, :messages)
                                             .order(last_message_at: :desc)

    render json: {
      waitingConversations: waiting_conversations.map { |c| format_conversation(c) },
      assignedConversations: assigned_conversations.map { |c| format_conversation(c) }
    }
  end

  # POST /expert/conversations/:conversation_id/claim
  def claim
    if @conversation.assigned_expert_id.present?
      return render json: { error: 'Conversation is already assigned' }, 
                    status: :unprocessable_entity
    end

    if @conversation.update(assigned_expert: current_user_jwt, status: 'active')
      ExpertAssignment.create!(
        conversation: @conversation,
        expert: current_user_jwt,
        assigned_at: Time.now.utc,
        status: 'active'
      )
      render json: { success: true }, status: :ok
    else
      render json: { errors: @conversation.errors.full_messages },
             status: :unprocessable_entity
    end
  end

  # POST /expert/conversations/:conversation_id/unclaim
  def unclaim
    if @conversation.assigned_expert != current_user_jwt
      return render json: { error: 'You are not assigned to this conversation' }, 
                    status: :forbidden
    end

    if @conversation.update(assigned_expert: nil, status: 'waiting')
      assignment = ExpertAssignment.find_by(
        conversation: @conversation,
        expert: current_user_jwt,
        status: 'active'
      )
      assignment&.update!(status: 'unassigned', resolved_at: Time.now.utc)
      
      render json: { success: true }, status: :ok
    else
      render json: { errors: @conversation.errors.full_messages },
             status: :unprocessable_entity
    end
  end

  # GET /expert/profile
  def get_profile
    render json: format_expert_profile(@profile)
  end

  # PUT /expert/profile
  def update_profile
    if profile_params.key?(:bio)
      @profile.bio = profile_params[:bio]
    end
    
    if profile_params.key?(:knowledgeBaseLinks)
      @profile.knowledge_base_links = profile_params[:knowledgeBaseLinks]
    end

    if @profile.save
      render json: format_expert_profile(@profile), status: :ok
    else
      render json: { errors: @profile.errors.full_messages },
             status: :unprocessable_entity
    end
  end

  # GET /expert/assignments/history
  def assignment_history
    assignments = ExpertAssignment.where(expert: current_user_jwt)
                                  .order(assigned_at: :desc)
    render json: assignments.map { |a| format_expert_assignment(a) }
  end

  private

  def set_conversation
    @conversation = Conversation.find_by(id: params[:conversation_id])
    unless @conversation
      render json: { error: 'Conversation not found' }, status: :not_found and return
    end
  end

  def set_expert_profile
    @profile = current_user_jwt.expert_profile
    unless @profile
      render json: { error: 'Expert profile not found' }, status: :not_found and return
    end
  end

  def profile_params
    params.permit(:bio, knowledgeBaseLinks: [])
  end

  def format_expert_profile(profile)
    {
      id: profile.id.to_s,
      userId: profile.user_id.to_s,
      bio: profile.bio,
      knowledgeBaseLinks: profile.knowledge_base_links,
      createdAt: profile.created_at,
      updatedAt: profile.updated_at
    }
  end

  def format_expert_assignment(assignment)
    {
      id: assignment.id.to_s,
      conversationId: assignment.conversation_id.to_s,
      expertId: assignment.expert_id.to_s,
      status: assignment.status,
      assignedAt: assignment.assigned_at,
      resolvedAt: assignment.resolved_at,
      rating: 5
    }
  end
end