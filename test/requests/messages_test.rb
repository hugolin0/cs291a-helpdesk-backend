require "test_helper"

class MessagesTest < ActionDispatch::IntegrationTest
  def setup
    # Create users
    @user = User.create!(username: "initiator_user", password: "password123")
    @expert_user = User.create!(username: "expert_user", password: "password123")
    @other_user = User.create!(username: "other_user", password: "password123")
    
    # Create tokens
    @user_token = JwtService.encode(@user)
    @expert_token = JwtService.encode(@expert_user)
    @other_token = JwtService.encode(@other_user)

    # Create conversation
    @conversation = Conversation.create!(
      title: "Test Conversation",
      initiator: @user,
      assigned_expert: @expert_user,
      status: "active"
    )

    # Create pre-existing messages
    @message_from_user = @conversation.messages.create!(
      sender: @user,
      sender_role: "initiator",
      content: "Hello from initiator"
    )
    @message_from_expert = @conversation.messages.create!(
      sender: @expert_user,
      sender_role: "expert",
      content: "Hello from expert"
    )
  end

  # --- GET /conversations/:conversation_id/messages ---

  test "GET /conversations/:id/messages returns all messages for initiator" do
    get "/conversations/#{@conversation.id}/messages", 
        headers: { "Authorization" => "Bearer #{@user_token}" }
    
    assert_response :ok
    response_data = JSON.parse(response.body)
    assert_equal 2, response_data.length
    assert_equal "Hello from initiator", response_data.first["content"]
  end

  test "GET /conversations/:id/messages returns all messages for expert" do
    get "/conversations/#{@conversation.id}/messages",
        headers: { "Authorization" => "Bearer #{@expert_token}" }
    
    assert_response :ok
    assert_equal 2, JSON.parse(response.body).length
  end

  test "GET /conversations/:id/messages requires authentication" do
    get "/conversations/#{@conversation.id}/messages"
    assert_response :unauthorized
  end

  test "GET /conversations/:id/messages returns not found for non-existent conversation" do
    get "/conversations/999999/messages", 
        headers: { "Authorization" => "Bearer #{@user_token}" }
    
    assert_response :not_found
    response_data = JSON.parse(response.body)
    assert_equal "Conversation not found", response_data["error"]
  end



  # --- POST /messages ---

  test "POST /messages creates a new message as initiator" do
    assert_difference("Message.count", 1) do
      post "/messages",
           params: { conversationId: @conversation.id, content: "New message" },
           headers: { "Authorization" => "Bearer #{@user_token}" }
    end
    
    assert_response :created
    response_data = JSON.parse(response.body)
    assert_equal "New message", response_data["content"]
    assert_equal @user.id.to_s, response_data["senderId"]
    assert_equal "initiator", response_data["senderRole"]
  end

  test "POST /messages creates a new message as expert" do
    assert_difference("Message.count", 1) do
      post "/messages",
           params: { conversationId: @conversation.id, content: "New reply" },
           headers: { "Authorization" => "Bearer #{@expert_token}" }
    end

    assert_response :created
    response_data = JSON.parse(response.body)
    assert_equal "New reply", response_data["content"]
    assert_equal @expert_user.id.to_s, response_data["senderId"]
    assert_equal "expert", response_data["senderRole"]
  end

  test "POST /messages updates conversation's last_message_at" do
    original_time = @conversation.last_message_at
    sleep 0.1 # Ensure time difference
    
    post "/messages",
         params: { conversationId: @conversation.id, content: "Timestamp test" },
         headers: { "Authorization" => "Bearer #{@user_token}" }
    
    assert_response :created
    @conversation.reload
    assert_not_equal original_time, @conversation.last_message_at
  end

  test "POST /messages requires content" do
    post "/messages",
         params: { conversationId: @conversation.id, content: "" },
         headers: { "Authorization" => "Bearer #{@user_token}" }
    
    assert_response :unprocessable_entity
    assert_includes JSON.parse(response.body)["errors"], "Content can't be blank"
  end

  test "POST /messages requires participation" do
    post "/messages",
         params: { conversationId: @conversation.id, content: "I am a hacker" },
         headers: { "Authorization" => "Bearer #{@other_token}" }
    
    assert_response :not_found
  end

  test "POST /messages returns not found for non-existent conversation" do
    post "/messages",
         params: { conversationId: 999999, content: "Test message" },
         headers: { "Authorization" => "Bearer #{@user_token}" }
    
    assert_response :not_found
    response_data = JSON.parse(response.body)
    assert_equal "Conversation not found", response_data["error"]
  end


  # --- PUT /messages/:id/read ---

  test "PUT /messages/:id/read marks a message as read" do
    # User marks the expert's message as read
    put "/messages/#{@message_from_expert.id}/read",
        headers: { "Authorization" => "Bearer #{@user_token}" }
    
    assert_response :ok
    assert_equal true, @message_from_expert.reload.is_read
    assert_equal({ "success" => true }, JSON.parse(response.body))
  end

  test "PUT /messages/:id/read forbids marking own message as read" do
    # User tries to mark their *own* message as read
    put "/messages/#{@message_from_user.id}/read",
        headers: { "Authorization" => "Bearer #{@user_token}" }
    
    assert_response :forbidden
    assert_equal false, @message_from_user.reload.is_read
    assert_equal({ "error" => "Cannot mark your own messages as read" }, JSON.parse(response.body))
  end

  test "PUT /messages/:id/read requires authentication" do
    put "/messages/#{@message_from_expert.id}/read"
    assert_response :unauthorized
  end


end