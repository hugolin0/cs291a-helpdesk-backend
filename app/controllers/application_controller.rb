class ApplicationController < ActionController::API

  include ActionController::Cookies

  private

  # Helper to find the user from the session
  def current_user_session
    @current_user_session ||= User.find_by(id: session[:user_id])
  end

  # Filter to protect endpoints
  def authorize_session!
    unless current_user_session
      render json: { error: 'No session found' }, status: :unauthorized and return
    end
  end

  # Finds the user based on the Authorization: Bearer <token> header
  def current_user_jwt
    token = request.headers['Authorization']&.split(' ')&.last
    return nil unless token

    begin
      decoded_token = JwtService.decode(token)
      return nil unless decoded_token
      @current_user_jwt ||= User.find_by(id: decoded_token[:user_id])
    rescue JWT::DecodeError
      nil
    end
  end

  # A before_action to protect JWT-based endpoints
  def authorize_jwt!
    unless current_user_jwt
      render json: { error: 'Not authorized' }, status: :unauthorized
      return
    end
  end

  def format_conversation(convo)
    {
      id: convo.id.to_s,
      title: convo.title,
      status: convo.status,
      questionerId: convo.initiator&.id&.to_s,
      questionerUsername: convo.initiator&.username,
      assignedExpertId: convo.assigned_expert&.id&.to_s,
      assignedExpertUsername: convo.assigned_expert&.username,
      createdAt: convo.created_at.iso8601,
      updatedAt: convo.updated_at.iso8601,
      lastMessageAt: convo.last_message_at&.iso8601,
      unreadCount: convo.messages.where.not(sender: current_user_jwt).where(is_read: false).count
    }
  end

  def format_message(message)
    {
      id: message.id.to_s,
      conversationId: message.conversation_id.to_s,
      senderId: message.sender_id.to_s,
      senderUsername: message.sender.username,
      senderRole: message.sender_role,
      content: message.content,
      timestamp: message.created_at.iso8601,
      isRead: message.is_read
    }
  end
end
