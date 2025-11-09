# app/controllers/auth_controller.rb
class AuthController < ApplicationController
  before_action :authorize_session!, only: [:me, :refresh]
  
  # POST /auth/register
  def register
    user = User.new(user_params)
    
    if user.save
      # Automatically create expert profile for new users
      ExpertProfile.create!(user: user, bio: "", knowledge_base_links: [])
      
      # Set session
      session[:user_id] = user.id
      
      # Generate JWT token
      token = JwtService.encode(user)
      
      render json: {
        user: user_json(user),
        token: token
      }, status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end
  
  # POST /auth/login
  def login
    user = User.find_by(username: params[:username])
    
    if user&.authenticate(params[:password])
      # Set session
      session[:user_id] = user.id
      
      # Update last_active_at
      user.update(last_active_at: Time.current)
      
      # Generate JWT token
      token = JwtService.encode(user)
      
      render json: {
        user: user_json(user),
        token: token
      }, status: :ok
    else
      render json: { error: 'Invalid username or password' }, status: :unauthorized
    end
  end
  
  # POST /auth/logout
  def logout
    reset_session
    
    render json: { message: 'Logged out successfully' }, status: :ok
  end
  
  # POST /auth/refresh
  def refresh
    current_user_session.update(last_active_at: Time.current)
    token = JwtService.encode(current_user_session)
    render json: { user: user_json(current_user_session), token: token }, status: :ok
  end
  
  # GET /auth/me
  def me
    render json: user_json(current_user_session), status: :ok
  end
  
  private
  
  def user_params
    params.permit(:username, :password)
  end
  
  def user_json(user)
    {
      id: user.id,
      username: user.username,
      created_at: user.created_at.iso8601,
      last_active_at: user.last_active_at&.iso8601
    }
  end
end