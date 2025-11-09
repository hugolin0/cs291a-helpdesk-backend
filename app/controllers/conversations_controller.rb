class ConversationsController < ApplicationController
  before_action :authorize_jwt!

  def index
    conversations = current_user_jwt.initiated_conversations.or(
      current_user_jwt.assigned_conversations
    ).includes(:initiator, :assigned_expert)

    render json: conversations.map { |c| format_conversation(c) }
  end

  def show
    conversation = Conversation.find_by(id: params[:id])
    if conversation && (conversation.initiator == current_user_jwt)
      render json: format_conversation(conversation)
    else
      render json: { error: 'Conversation not found' }, status: :not_found
    end
  end

  def create
    conversation = current_user_jwt.initiated_conversations.build(conversation_params)
    conversation.status = 'waiting'

    if conversation.save
      render json: format_conversation(conversation), status: :created
    else
      render json: { errors: conversation.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def conversation_params
    params.permit(:title)
  end
end
