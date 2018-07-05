require 'resque/server'

Rails.application.routes.draw do

  root to: 'products#top'

  get 'products/top'

  get 'products/get_yahoo'
  get 'products/get_amazon'

  get 'products/search'
  post 'products/search'

  post 'products/output'

  post 'products/check'

  post 'products/regist'

  get 'products/setup'
  post 'products/setup'

  mount Resque::Server.new, at: "/resque"

  devise_scope :user do
    get '/users/sign_out' => 'devise/sessions#destroy'
    get '/sign_in' => 'devise/sessions#new'
  end
  mount RailsAdmin::Engine => '/admin', as: 'rails_admin'
  devise_for :users, :controllers => {
   :registrations => 'users/registrations'
  }

  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
