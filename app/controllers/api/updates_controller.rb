class Api::UpdatesController < ApplicationController
  before_action :authorize_jwt!
  before_action :authorize_user!, only: [:conversations, :messages]
  before_action :authorize_expert!, only: [:expert_queue]

  # GET /api/conversations/updates?userId=X&since=Y
  def conversations
    since_time = parse_since(params[:since])
    
    conversations = Conversation
      .where("initiator_id = :user_id OR assigned_expert_id = :user_id", user_id: params[:userId])
      .where("updated_at > ?", since_time)
      .includes(:initiator, :assigned_expert, :messages)
      
    render json: conversations.map { |c| format_conversation(c) }
  end

  # GET /api/messages/updates?userId=X&since=Y
  def messages
    since_time = parse_since(params[:since])
    
    # Find conversations user is part of
    conversation_ids = Conversation
      .where("initiator_id = :user_id OR assigned_expert_id = :user_id", user_id: params[:userId])
      .pluck(:id)
      
    messages = Message
      .where(conversation_id: conversation_ids)
      .where("created_at > ?", since_time)
      .where.not(sender_id: params[:userId]) 
      .includes(:sender)
      
    render json: messages.map { |m| format_message(m) }
  end

  # GET /api/expert-queue/updates?expertId=X&since=Y
  def expert_queue
    since_time = parse_since(params[:since])
    
    waiting = Conversation
      .where(status: 'waiting')
      .where("updated_at > ?", since_time)
      .includes(:initiator, :assigned_expert, :messages)
      
    assigned = current_user_jwt
      .assigned_conversations
      .where("updated_at > ?", since_time)
      .includes(:initiator, :assigned_expert, :messages)
      
    render json: {
      waitingConversations: waiting.map { |c| format_conversation(c) },
      assignedConversations: assigned.map { |c| format_conversation(c) }
    }
  end

  private

  # --- Authorization Helpers ---

  def authorize_user!
    if params[:userId].to_i != current_user_jwt.id
      render json: { error: "Forbidden" }, status: :forbidden and return
    end
  end

  def authorize_expert!
    if params[:expertId].to_i != current_user_jwt.id
      render json: { error: "Forbidden" }, status: :forbidden and return
    end
  end
  
  def parse_since(since_param)
    since_param.present? ? DateTime.iso8601(since_param) : Time.at(0)
  rescue ArgumentError
    Time.at(0)
  end


end