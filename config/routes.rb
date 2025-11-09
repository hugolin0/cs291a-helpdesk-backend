Rails.application.routes.draw do
  get 'health' => 'health#index'
  post '/auth/register', to: 'auth#register'
  post '/auth/login', to: 'auth#login'
  post '/auth/logout', to: 'auth#logout'
  post '/auth/refresh', to: 'auth#refresh'
  get '/auth/me', to: 'auth#me'
  
  # Conversations routes
  resources :conversations, only: [:index, :show, :create] do
    resources :messages, only: [:index], controller: 'messages'
  end

  # Messages (JWT-based)
  # POST /messages (not nested, requires conversationId in body)
  resources :messages, only: [:create] do
    # Member route for marking as read
    member do
      put :read
    end
  end

  # Expert Operations (JWT-based)
  scope '/expert' do
    get "/queue", to: "expert#queue"
    post "/conversations/:conversation_id/claim", to: "expert#claim"
    post "/conversations/:conversation_id/unclaim", to: "expert#unclaim"
    get "/profile", to: "expert#get_profile"
    put "/profile", to: "expert#update_profile"
    get "/assignments/history", to: "expert#assignment_history"
  end

  # Update/Polling Endpoints (JWT-based)
  namespace :api do
    get "/conversations/updates", to: "updates#conversations"
    get "/messages/updates", to: "updates#messages"
    get "/expert-queue/updates", to: "updates#expert_queue"
  end

  
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
end
