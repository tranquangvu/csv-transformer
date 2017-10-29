Rails.application.routes.draw do
  devise_for :users

  post 'transform', to: 'home#transform'
  root 'home#index'
end
