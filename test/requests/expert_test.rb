require "test_helper"

class ExpertTest < ActionDispatch::IntegrationTest
  def setup

    ExpertAssignment.destroy_all
    Conversation.destroy_all
    ExpertProfile.destroy_all
    User.destroy_all

    @initiator_user = User.create!(username: "testuser", password: "password123")
    @expert_user = User.create!(username: "expertuser", password: "password123")
    @other_expert = User.create!(username: "other_expert", password: "password123")
    ExpertProfile.create!(user: @expert_user, bio: "Initial Bio")
    ExpertProfile.create!(user: @other_expert, bio: "Other Bio")

    @expert_token = JwtService.encode(@expert_user)
    @other_expert_token = JwtService.encode(@other_expert)

    @waiting_convo = Conversation.create!(
      title: "Waiting Convo",
      initiator: @initiator_user,
      status: "waiting"
    )
    
    @assigned_convo = Conversation.create!(
      title: "Assigned Convo",
      initiator: @initiator_user,
      assigned_expert: @expert_user,
      status: "active"
    )

    @assignment_history = ExpertAssignment.create!(
      conversation: @assigned_convo,
      expert: @expert_user,
      status: "active",
      assigned_at: Time.now.utc
    )
  end

  # --- GET /expert/queue ---

  test "GET /expert/queue requires authentication" do
    get "/expert/queue"
    assert_response :unauthorized
  end

  test "GET /expert/queue returns waiting and assigned conversations" do
    get "/expert/queue", headers: { "Authorization" => "Bearer #{@expert_token}" }
    
    assert_response :ok
    response_data = JSON.parse(response.body)
    
    assert response_data.key?("waitingConversations")
    assert response_data.key?("assignedConversations")
    
    assert_equal 1, response_data["waitingConversations"].length
    assert_equal @waiting_convo.id.to_s, response_data["waitingConversations"].first["id"]
    
    assert_equal 1, response_data["assignedConversations"].length
    assert_equal @assigned_convo.id.to_s, response_data["assignedConversations"].first["id"]
  end

  # --- POST /expert/conversations/:id/claim ---

  test "POST /claim assigns a waiting conversation to the expert" do
    assert_difference("ExpertAssignment.count", 1) do
      post "/expert/conversations/#{@waiting_convo.id}/claim",
           headers: { "Authorization" => "Bearer #{@expert_token}" }
    end
    
    assert_response :ok
    assert_equal({ "success" => true }, JSON.parse(response.body))
    
    @waiting_convo.reload
    assert_equal @expert_user, @waiting_convo.assigned_expert
    assert_equal "active", @waiting_convo.status
  end

  test "POST /claim fails if conversation is already assigned" do
    post "/expert/conversations/#{@assigned_convo.id}/claim",
         headers: { "Authorization" => "Bearer #{@expert_token}" }
    
    assert_response :unprocessable_entity
    assert_equal "Conversation is already assigned", JSON.parse(response.body)["error"]
  end

  test "POST /claim fails for non-existent conversation" do
    post "/expert/conversations/99999/claim",
         headers: { "Authorization" => "Bearer #{@expert_token}" }
    assert_response :not_found
  end

  # --- POST /expert/conversations/:id/unclaim ---

  test "POST /unclaim releases an assigned conversation" do
    post "/expert/conversations/#{@assigned_convo.id}/unclaim",
         headers: { "Authorization" => "Bearer #{@expert_token}" }
    
    assert_response :ok
    assert_equal({ "success" => true }, JSON.parse(response.body))
    
    @assigned_convo.reload
    assert_nil @assigned_convo.assigned_expert
    assert_equal "waiting", @assigned_convo.status

    @assignment_history.reload
    assert_equal "unassigned", @assignment_history.status
    assert_not_nil @assignment_history.resolved_at
  end

  test "POST /unclaim fails if not assigned to the expert" do
    post "/expert/conversations/#{@assigned_convo.id}/unclaim",
         headers: { "Authorization" => "Bearer #{@other_expert_token}" }
    
    assert_response :forbidden
    assert_equal "You are not assigned to this conversation", JSON.parse(response.body)["error"]
  end

  test "POST /unclaim fails if conversation is unassigned" do
    post "/expert/conversations/#{@waiting_convo.id}/unclaim",
         headers: { "Authorization" => "Bearer #{@expert_token}" }
    
    assert_response :forbidden
  end

  # --- GET /expert/profile ---

  test "GET /expert/profile returns the expert's profile" do
    profile = @expert_user.expert_profile
    profile.update(bio: "Test bio")
    
    get "/expert/profile", headers: { "Authorization" => "Bearer #{@expert_token}" }
    assert_response :ok
    
    response_data = JSON.parse(response.body)
    assert_equal profile.id.to_s, response_data["id"]
    assert_equal "Test bio", response_data["bio"]
  end

  # --- PUT /expert/profile ---

  test "PUT /expert/profile updates the expert's profile" do
    profile = @expert_user.expert_profile
    new_bio = "This is my new bio."
    new_links = ["http://example.com"]
    
    put "/expert/profile",
        params: { bio: new_bio, knowledgeBaseLinks: new_links },
        headers: { "Authorization" => "Bearer #{@expert_token}" }
        
    assert_response :ok
    
    profile.reload
    assert_equal new_bio, profile.bio
    assert_equal new_links, profile.knowledge_base_links
    
    response_data = JSON.parse(response.body)
    assert_equal new_bio, response_data["bio"]
  end

  # --- GET /expert/assignments/history ---

  test "GET /expert/assignments/history returns assignment history" do
    get "/expert/assignments/history", headers: { "Authorization" => "Bearer #{@expert_token}" }
    
    assert_response :ok
    response_data = JSON.parse(response.body)
    
    assert_equal 1, response_data.length
    assert_equal @assignment_history.id.to_s, response_data.first["id"]
    assert_equal @assigned_convo.id.to_s, response_data.first["conversationId"]
  end
end