class ProductsController < ApplicationController

  require 'nokogiri'
  require 'uri'
  require 'csv'
  require 'peddler'
  require 'typhoeus'
  require 'date'
  require 'kconv'
  require 'activerecord-import'
  

  before_action :authenticate_user!, :except => [:check, :regist]
  protect_from_forgery :except => [:check, :regist]

  rescue_from CanCan::AccessDenied do |exception|
    redirect_to root_url, :alert => exception.message
  end

  def search
    @login_user = current_user
    @account = Account.find_by(user: current_user.email)
    @limitnum = 19

    if @account != nil then
      uid = Account.find_by(user: current_user.email).unique_id
      #@products = Product.where(user: current_user.email, unique_id: uid, isvalid: true).where("profit > 0").order("profit DESC").limit(ENV['SHOW_NUM'])
      @products = Product.where(user: current_user.email, unique_id: uid, isvalid: true).order("profit DESC").limit(ENV['SHOW_NUM'])
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
        @account.update(amazon_url: data.path)
      else
        @account.update(amazon_url: arg2)
        arg3 = nil
      end
      sleep(2)
      t = Time.now
      strTime = t.strftime("%Y年%m月%d日 %H時%M分")

      queue_name = 'load_asin_' + current_user.email

      cflg = true
      workers = Resque.workers
      workers.each do |w|
        qq = w.job['queue']
        if qq == queue_name && w.working? then
          cflg = false
        end
      end

      if Resque.size(queue_name) == 0 && cflg then
        @account.msend(
          "===================================\n【ヤフープレミアムハンター】\nリサーチを受け付けました。\n開始時間：" + strTime + "\n条件：" + arg1.to_s + " " + arg2,
          @account.cw_api_token,
          @account.cw_room_id
        )
        @account.update(asin_status: "実行中", amazon_status: "準備中", yahoo_status: "準備中")
        LoadAsinJob.set(queue: queue_name).perform_later(current_user.email, arg1, arg2, arg3, @limitnum)
      end
      #redirect_to products_search_path
    end
  end

  def top
    @login_user = current_user
    @account = Account.find_by(user: current_user.email)
    temp = Product.where(listing: true)
    #@products = temp.order("RANDOM()").limit(6)
    @products = temp.sample(6)
    @comment = Messenger.order("created_at DESC").first(3)
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

        cc = temp.listing_count.to_i + 1
        temp.update(listing: true, listing_count: cc)
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
            when 15 then
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
      fname = "出品CSV_" + strTime + ".txt"
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

  def contact
    @login_user = current_user
    @account = Account.find_or_create_by(user:current_user.email)
  end

  def check
    if request.post? then
      user = params[:user]
      password = params[:password]
      check = Account.find_by(user: user, password: password)
      if check != nil then
        if check.isvalid == true then
          head 200   # 200を返す
        else
          head 304   # 200を返す
        end
      else
        head 304   # 200を返す
      end
    end
    redirect_to products_top_path
  end

  def regist
    if request.post? then
      user = params[:user]
      password = params[:password]
      ulevel = params[:ulevel]
      logger.debug("====== Regist from Form =======")
      logger.debug(user)
      logger.debug(password)
      logger.debug(ulevel)
      tuser = User.find_or_initialize_by(email: user)
      if tuser.new_record? # 新規作成の場合は保存
        tuser = User.create(email: user, password: password)
      end
      tuser = Account.find_or_create_by(user: user)
      tuser.update(user_level: ulevel)
      logger.debug("====== Regist from Form End =======")
    end
    redirect_to products_top_path
  end

  def list
    @login_user = current_user
    @account = Account.find_by(user: current_user.email)
    temp = Product.where(user: current_user.email, listing: true)
    @products = temp
    respond_to do |format|
      format.html do

      end
      format.csv do
        tt = Time.now
        strTime = tt.strftime("%Y%m%D%H%M%S")
        fname = "出品リスト_" + strTime + ".csv"
        send_data render_to_string, filename: fname, type: :csv
      end
    end
  end

  def get_amazon
    account = Account.find_by(user: current_user.email)
    uid = account.unique_id
    queue_name = 'get_amazon_' + current_user.email
    sleep(2)

    cflg = true
    workers = Resque.workers
    workers.each do |w|
      qq = w.job['queue']
      if qq == queue_name && w.working? then
        cflg = false
      end
    end

    if Resque.size(queue_name) == 0 && cflg then
      account.update(asin_status: "再取得準備中")
      GetItemDataJob.set(queue: queue_name).perform_later(current_user.email, uid)
    end
    redirect_to products_search_path
  end

  def get_yahoo
    account = Account.find_by(user: current_user.email)
    uid = account.unique_id
    queue_name = 'get_yahoo_' + current_user.email
    sleep(2)
    cflg = true
    workers = Resque.workers
    workers.each do |w|
      qq = w.job['queue']
      if qq == queue_name && w.working? then
        cflg = false
      end
    end

    if Resque.size(queue_name) == 0 && cflg then
      account.update(yahoo_status: "再取得準備中")
      GetYahooDataJob.set(queue: queue_name).perform_later(current_user.email, uid)
    end
    redirect_to products_search_path
  end

  def get_asin
    @login_user = current_user
    @account = Account.find_by(user: current_user.email)
    @limitnum = 19
    if @account != nil then
      uid = Account.find_by(user: current_user.email).unique_id
      @products = Product.where(user: current_user.email, unique_id: uid, isvalid: true).where("profit > 0").order("profit DESC").limit(ENV['SHOW_NUM'])
    else
      @account = Account.new
      @products = nil
    end

    arg1 = 'from_url'
    arg2 = @account.amazon_url
    data = nil
    if data != nil then
      arg3 = CSV.read(data.path)
      @account.update(amazon_url: data.path)
    else
      @account.update(amazon_url: arg2)
      arg3 = nil
    end
    GetAsinJob.perform_later(current_user.email, arg1, arg2, arg3, @limitnum)
    redirect_to products_search_path
  end

  def destroy
    @product = Product.find(params[:id])
    @product.update(
      listing: false
    )
    redirect_to products_list_path
  end

  private
  def user_params
     params.require(:account).permit(:user, :seller_id, :mws_auth_token, :cw_api_token, :cw_room_id, :condition_note, :lead_time, :softbank, :premium)
  end

end
