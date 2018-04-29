class ProductsController < ApplicationController

  require 'nokogiri'
  require 'uri'
  require 'csv'
  require 'peddler'
  require 'typhoeus'

  before_action :authenticate_user!

  rescue_from CanCan::AccessDenied do |exception|
    redirect_to root_url, :alert => exception.message
  end

  def search
  end

  def upload
  end
end
