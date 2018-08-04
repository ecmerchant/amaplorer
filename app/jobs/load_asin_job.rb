class LoadAsinJob < ApplicationJob
  queue_as :default
  require 'nokogiri'
  require 'open-uri'
  require 'activerecord-import'

  rescue_from(StandardError) do |exception|
    # Do something with the exception
    logger.debug("Standard Error Escape Active Job")
    logger.error exception
  end

  def perform(user, arg1, arg2, arg3, limitnum)

    logger.debug('======= GET ASIN =========')
    condition = arg1
    charset = "UTF-8"
    i = 1
    account = Account.find_by(user: user)
    account.update(asin_status: "実行中", amazon_status: "準備中", yahoo_status: "準備中")
    ecounter = 0
    cc = 0
    upto = 5
    casins = Hash.new

    ulevel = account.user_level
    counter = 0
    d = DateTime.now
    uid = d.strftime("%Y%m%d%H%M%S")
    #tu = Account.find_by(user: user)
    account.update(unique_id: uid)
    asin_list = Array.new
    ua = CSV.read('app/others/User-Agent.csv', headers: false, col_sep: "\t")
    uanum = ua.length
    user_agent = ua[rand(uanum)][0]
    logger.debug("user_agent:" + user_agent)

    if condition == 'from_url' then
      #ASINの入力方法:URLの場合
      logger.debug('条件：URL')
      org_url = arg2
      #asin = Array.new
      #URLからASINリストの作成
      loop do
        begin
          url = org_url + '&page=' + i.to_s
          logger.debug("URL：" + url)
          sleep(1.1)
          cc = 0
          begin
            html = open(url, "User-Agent" => user_agent) do |f|
              charset = f.charset
              f.read # htmlを読み込んで変数htmlに渡す
            end
          rescue OpenURI::HTTPError => error
            response = error.io
            logger.debug("\nNo." + i.to_s + "\n")
            logger.debug("error!!\n")
            logger.debug(error)
            cc += 1
            retry if cc < upto
            next
          end

          doc = Nokogiri::HTML.parse(html, nil)
          asins = doc.css('li/@data-asin')

          #終了条件1：検索結果がヒットしない
          hbody = html.force_encoding("UTF-8")
          rnum = hbody.match(/<span id="s-result-count">([\s\S]*?)</)
          logger.debug("==========================")
          if rnum != nil then
            logger.debug(rnum[1])
          end
          logger.debug("==========================")

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
            #asin.push(temp_asin)
            tag = temp_asin.to_s

            if casins.key?(tag) == false then
              asin_list << Product.new(user:user, asin:tag, unique_id: uid, isvalid: true)
              casins[tag] = ecounter
              ecounter += 1
            end

            logger.debug(tag)
            #asin_list << Product.new(user:user, asin:tag, unique_id: uid, isvalid: true)
            #asin_list << Product.new(asin:tag)
            #temp = tproduct.find_or_create_by(asin:tag)
            #temp.update(unique_id: uid, isvalid: true)

            if ulevel == "trial" then
              counter += 1
              if counter > limitnum then
                break
              end
            end
          end
          account.update(asin_status: "実行中 " + ecounter.to_s + "件済")
          #Product.import asin_list
        rescue => e
          logger.debug("エラーあり")
          logger.debug(e)
          break
        end
        doc = nil
        asins = nil
        i += 1
      end
    elsif condition == 'from_file' then
      #ASINの入力方法:ファイルからの場合
      asin = Array.new
      logger.debug('条件:ファイル')
      arg3.each do |row|
        logger.debug(row[0])
        asin.push(row[0].to_s.gsub("\n","").strip())
      end
      counter = 0
      asin.each do |tasin|
        tag = tasin.to_s
        logger.debug(tag)
        if casins.key?(tag) == false then
          asin_list << Product.new(user:user, asin:tag, unique_id: uid, isvalid: true)
          casins[tag] = ecounter
          ecounter += 1
        end
        #temp = tproduct.find_or_create_by(asin:tag)
        #ecounter += 1
        #temp.update(unique_id: uid, isvalid: true)

        if ulevel == "trial" then
          counter += 1
          if counter > limitnum then
            break
          end
        end
      end
      account.update(asin_status: "実行中 " + ecounter.to_s + "件済")
    end

    Product.import asin_list, on_duplicate_key_update: {constraint_name: :for_upsert, columns: [:unique_id, :isvalid]}
    asin_list = nil
    casins = nil
    #メモリ開放用
    logger.debug("\n====== GC START =========")
    ObjectSpace.each_object(ActiveRecord::Relation).each(&:reset)
    GC.start

    logger.debug('======= GET ASIN END =========')
    account.update(asin_status: "完了 " + ecounter.to_s + "件済")
    t = Time.now
    strTime = t.strftime("%Y年%m月%d日 %H時%M分")
    account.msend(
      "【ヤフープレミアムハンター】\nASIN取得完了しました。" + ecounter.to_s +  "件取得。\n終了時間："+strTime,
      account.cw_api_token,
      account.cw_room_id
    )

    a = Product.new
    #メモリ開放用
    logger.debug("\n====== GC START =========")
    ObjectSpace.each_object(ActiveRecord::Relation).each(&:reset)
    GC.start

    a.amazon(user, uid)
    a.yahoo_shopping(user, uid)

    #メモリ開放用
    logger.debug("\n====== GC START =========")
    ObjectSpace.each_object(ActiveRecord::Relation).each(&:reset)
    GC.start
    #GetItemDataJob.perform_later(current_user.email, uid)
  end
end
