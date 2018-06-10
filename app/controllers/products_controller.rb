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
    if @account != nil then
      uid = Account.find_by(user: current_user.email).unique_id
      @products = Product.where(user: current_user.email, unique_id: uid)
    else
      @account = Account.new
      @products = nil
    end
    if request.post? then
      #ASINの入力方法
      condition = params[:search][:condition]
      charset = "UTF-8"
      i = 1

      if condition = 'from_url' then
        #ASINの入力方法:URLの場合
        logger.debug('条件：URL')
        org_url = params[:search][:url]
        asin = Array.new
        #URLからASINリストの作成
        loop do
          begin
            url = org_url + '&page=' + i.to_s
            logger.debug("URL：" + url)

            request = Typhoeus::Request.new(url, followlocation: true)
            request.run
            html = request.response.body

            doc = Nokogiri::HTML.parse(html, nil, charset)
            asins = doc.css('li/@data-asin')

            #終了条件1：検索結果がヒットしない
            hbody = html.force_encoding("UTF-8")
            if hbody.include?("0件の検索結果") then
              logger.debug("検索結果なし")
              break
            end

            #終了条件2：ASINがヒットしない
            if asins.count == 0 then
              logger.debug("ASINなし")
              break
            end

            asins.each do |temp_asin|
              asin.push(temp_asin)
            end

          rescue => e
            logger.debug("エラーあり")
            logger.debug(e)
            break
          end
          i += 1
        end

      elsif condition == 'from_asin' then
        #ASINの入力方法:ファイルからの場合
        logger.debug('条件：ASIN')
        data = params[:file]
        csv = CSV.table(data.path)
      end

      d = DateTime.now
      uid = d.strftime("%Y%m%d%H%M%S")
      asin.each do |tasin|
        tag = tasin.to_s
        logger.debug(tag)
        temp = Product.find_or_create_by(user:current_user.email, asin:tag)
        temp.update(unique_id: uid)
      end

      tu = Account.find_by(user: current_user.email)
      tu.update(unique_id: uid)

      GetItemDataJob.perform_later(current_user.email, uid)
      redirect_to products_search_path
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
