require "test_helper"

class Api::UpdatesTest < ActionDispatch::IntegrationTest
  def setup
    # 1. Clean database
    ExpertAssignment.destroy_all
    Message.destroy_all
    Conversation.destroy_all
    ExpertProfile.destroy_all
    User.destroy_all

    # 2. Create users and tokens
    @user = User.create!(username: "poll_user", password: "password123")
    @expert = User.create!(username: "poll_expert", password: "password123")
    ExpertProfile.create!(user: @user)
    ExpertProfile.create!(user: @expert)
    @user_token = JwtService.encode(@user)
    @expert_token = JwtService.encode(@expert)

    # 3. Create "old" items
    @convo_old_waiting = Conversation.create!(initiator: @user, title: "Old Waiting", status: "waiting")
    @convo_old_active = Conversation.create!(initiator: @user, assigned_expert: @expert, title: "Old Active", status: "active")
    @msg_old_from_user = @convo_old_active.messages.create!(sender: @user, content: "Old message", sender_role: "initiator")
    
    # Force update timestamps to be in the past
    [User, Conversation, Message].each { |m| m.update_all(updated_at: 2.hours.ago, created_at: 2.hours.ago) }

    # 4. Store timestamp
    sleep 0.1 # Ensure clock tick
    @since_timestamp = Time.now.utc.iso8601
    sleep 0.1

    # 5. Create "new" items
    @convo_new_waiting = Conversation.create!(initiator: @user, title: "New Waiting", status: "waiting")
    @msg_new_from_expert = @convo_old_active.messages.create!(sender: @expert, content: "New message", sender_role: "expert")
    # This last message will have automatically updated @convo_old_active.updated_at
  end

  # --- Authorization Tests ---

  test "GET /conversations/updates requires authentication" do
    get "/api/conversations/updates"
    assert_response :unauthorized
  end

  test "GET /conversations/updates forbids user mismatch" do
    get "/api/conversations/updates",
        params: { userId: @user.id },
        headers: { "Authorization" => "Bearer #{@expert_token}" } # Wrong token
    assert_response :forbidden
  end

  test "GET /messages/updates requires authentication" do
    get "/api/messages/updates"
    assert_response :unauthorized
  end

  test "GET /messages/updates forbids user mismatch" do
    get "/api/messages/updates",
        params: { userId: @user.id },
        headers: { "Authorization" => "Bearer #{@expert_token}" } # Wrong token
    assert_response :forbidden
  end

  test "GET /expert-queue/updates requires authentication" do
    get "/api/expert-queue/updates"
    assert_response :unauthorized
  end

  test "GET /expert-queue/updates forbids expert mismatch" do
    get "/api/expert-queue/updates",
        params: { expertId: @expert.id },
        headers: { "Authorization" => "Bearer #{@user_token}" } # Wrong token
    assert_response :forbidden
  end

  # --- Endpoint Logic Tests ---

  test "GET /conversations/updates returns only updated conversations" do
    get "/api/conversations/updates",
        params: { userId: @user.id, since: @since_timestamp },
        headers: { "Authorization" => "Bearer #{@user_token}" }
        
    assert_response :ok
    response_data = JSON.parse(response.body)
    response_ids = response_data.map { |c| c["id"].to_i }

    assert_equal 2, response_data.length
    assert_includes response_ids, @convo_new_waiting.id
    assert_includes response_ids, @convo_old_active.id # Updated by new message
    assert_not_includes response_ids, @convo_old_waiting.id
  end

  test "GET /messages/updates returns only new messages from others" do
    get "/api/messages/updates",
        params: { userId: @user.id, since: @since_timestamp },
        headers: { "Authorization" => "Bearer #{@user_token}" }
        
    assert_response :ok
    response_data = JSON.parse(response.body)
    response_ids = response_data.map { |m| m["id"].to_i }
    
    assert_equal 1, response_data.length
    assert_includes response_ids, @msg_new_from_expert.id
    assert_not_includes response_ids, @msg_old_from_user.id
  end

  test "GET /expert-queue/updates returns updated queues" do
    get "/api/expert-queue/updates",
        params: { expertId: @expert.id, since: @since_timestamp },
        headers: { "Authorization" => "Bearer #{@expert_token}" }
        
    assert_response :ok
    response_data = JSON.parse(response.body)
    
    waiting_ids = response_data["waitingConversations"].map { |c| c["id"].to_i }
    assigned_ids = response_data["assignedConversations"].map { |c| c["id"].to_i }

    assert_equal 1, waiting_ids.length
    assert_includes waiting_ids, @convo_new_waiting.id

    assert_equal 1, assigned_ids.length
    assert_includes assigned_ids, @convo_old_active.id # Updated by new message
  end
end