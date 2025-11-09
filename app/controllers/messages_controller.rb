class MessagesController < ApplicationController
  before_action :authorize_jwt!

  # GET /conversations/:conversation_id/messages
  def index
    @conversation = Conversation.find_by(id: params[:conversation_id])
    unless @conversation
      render json: { error: 'Conversation not found' }, status: :not_found and return
    end

    @messages = @conversation.messages.includes(:sender).order(:created_at)
    render json: @messages.map { |msg| format_message(msg) }
  end

  # POST /messages
  def create
    @conversation = Conversation.find_by(id: params[:conversationId])

    unless @conversation
      return render json: { error: 'Conversation not found' }, status: :not_found
    end

    sender_role = if @conversation.initiator == current_user_jwt
                    'initiator'
                  elsif @conversation.assigned_expert == current_user_jwt
                    'expert'
                  else
                    return render json: { error: 'Conversation not found' }, status: :not_found
                  end

    @message = @conversation.messages.build(
      content: params[:content],
      sender: current_user_jwt,
      sender_role: sender_role
    )

    if @message.save
      @conversation.update(last_message_at: @message.created_at)
      render json: format_message(@message), status: :created
    else
      render json: { errors: @message.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PUT /messages/:id/read
  def read
    @message = Message.find_by(id: params[:id])
    unless @message
      render json: { error: 'Message not found' }, status: :not_found and return
    end

    if @message.sender == current_user_jwt
      return render json: { error: 'Cannot mark your own messages as read' }, 
                    status: :forbidden
    end

    if @message.update(is_read: true)
      render json: { success: true }, status: :ok
    else
      render json: { errors: @message.errors.full_messages }, 
             status: :unprocessable_entity
    end
  end
end