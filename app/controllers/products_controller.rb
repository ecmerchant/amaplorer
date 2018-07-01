class ProductsController < ApplicationController

  require 'nokogiri'
  require 'uri'
  require 'csv'
  require 'peddler'
  require 'typhoeus'
  require "date"
  require 'kconv'

  before_action :authenticate_user!

  rescue_from CanCan::AccessDenied do |exception|
    redirect_to root_url, :alert => exception.message
  end

  def search
    @login_user = current_user
    @account = Account.find_by(user: current_user.email)
    @limitnum = 19
    if @account != nil then
      uid = Account.find_by(user: current_user.email).unique_id
      @products = Product.where(user: current_user.email, unique_id: uid)
    else
      @account = Account.new
      @products = nil
    end
    if request.post? then
      arg1 = params[:search][:condition]
      arg2 = params[:search][:url]
      data = params[:file]
      if data != nil then
        arg3 = CSV.read(data.path)
      else
        arg3 = nil
      end
      LoadAsinJob.perform_later(current_user.email, arg1, arg2, arg3, @limitnum)
      #redirect_to products_search_path
    end

  end

  def top
    @login_user = current_user
    @account = Account.find_by(user: current_user.email)
    temp = Product.where(listing: true)
    @products = temp.order("RANDOM()").limit(5)
  end

  def output
    @login_user = current_user
    data = params[:chk]

    if data != nil then
      logger.debug(data)
      stream = ""
      account = Account.find_by(user: current_user.email)
      File.open('app/others/Flat.File.Listingloader.jp.txt') do |file|
        file.each_line do |row|
          stream = stream + row
        end
      end

      products = Product.where(user: current_user.email)
      stream = stream.tosjis
      data.each do |key, value|
        temp = products.find_by(asin: key)
        temp.update(listing: true)
        logger.debug(stream.encoding)

        for p in 0..27
          case p
            when 0 then
              stream = stream + temp.yahoo_code + "\t"
            when 1 then
              if temp.cart_price != 0 then
                aprice = temp.cart_price.to_f + temp.cart_shipping.to_f
              else
                aprice = temp.lowest_price.to_f + temp.lowest_shipping.to_f
              end
              stream = stream + aprice.to_i.to_s + "\t"
            when 3 then
              stream = stream + "1" + "\t"
            when 4 then
              stream = stream + key + "\t"
            when 5 then
              stream = stream + "ASIN" + "\t"
            when 6 then
              stream = stream + "New" + "\t"
            when 7 then
              stream = stream + account.condition_note.to_s.tosjis + "\t"
            when 14 then
              stream = stream + account.lead_time.to_s.tosjis + "\t"
            when 27 then
              stream = stream + "" + "\n"
            else
              stream = stream + "" + "\t"
          end
        end
      end
      logger.debug(stream)
      t = Time.now
      strTime = t.strftime("%Y%m%D%H%M%S")
      fname = "出品CSV_" + strTime + ".csv"
      send_data(stream, filename: fname)
    else
      redirect_to products_search_path
    end
  end

  def setup
    @login_user = current_user
    @account = Account.find_or_create_by(user:current_user.email)
    if request.post? then
      @account.update(user_params)
    end
  end

  private
  def user_params
     params.require(:account).permit(:user, :seller_id, :mws_auth_token, :cw_api_token, :cw_room_id, :condition_note, :lead_time, :softbank, :premium)
  end

end
