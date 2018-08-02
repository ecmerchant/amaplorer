class GetAsinJob < ApplicationJob
  queue_as :default

  require 'nokogiri'
  require 'open-uri'
  require 'typhoeus'

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

    upto = 5
    cc = 0

    casins = Hash.new

    ulevel = account.user_level
    counter = 0
    d = DateTime.now
    uid = d.strftime("%Y%m%d%H%M%S")
    tu = Account.find_by(user: user)
    tu.update(unique_id: uid)
    if condition == 'from_url' then
      #ASINの入力方法:URLの場合
      logger.debug('条件：URL')
      org_url = arg2
      asin = Array.new
      #URLからASINリストの作成
      loop do
        begin
          url = org_url + '&page=' + i.to_s
          logger.debug("URL：" + url)

          ua = CSV.read('app/others/User-Agent.csv', headers: false, col_sep: "\t")
          uanum = ua.length
          user_agent = ua[rand(uanum)][0]
          logger.debug("user_agent:" + user_agent)
          sleep(1.1)
          cc = 0

=begin
          request = Typhoeus::Request.new(
            url,
            method: :get,
            followlocation: true,
            headers: {"User-Agent" => user_agent}
          )
          request.run
          html = request.response.body
=end

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
          hbody = html.force_encoding("UTF-8")

          rnum = hbody.match(/<span id="s-result-count">([\s\S]*?)</)
          logger.debug("=====================")
          if rnum != nil then
            logger.debug(rnum[1])
          end
          logger.debug("=====================")

          #終了条件1：検索結果がヒットしない
          if hbody.include?("0件の検索結果") then
            logger.debug("検索結果なし")
            logger.debug(hbody)
            break
          end

          if asins.count == 0 then
            logger.debug("====検索結果なし2====")
            break
          end

          #終了条件2：ASINがヒットしない
          #if asins.count == 0 then
          #  logger.debug("ASINなし")
          #  logger.debug(hbody)
          #  break
          #end

          asins.each do |temp_asin|

            asin.push(temp_asin)
            tag = temp_asin.to_s

            if casins.key?(tag) then

            else
              casins[tag] = ecounter
              ecounter += 1
            end

            logger.debug(tag)
            account.update(asin_status: "実行中 " + ecounter.to_s + "件済")
            temp = Product.find_or_create_by(user:user, asin:tag)
            temp.update(unique_id: uid, isvalid: true)

            if ulevel == "trial" then
              counter += 1
              if counter > limitnum then
                break
              end
            end
          end
          #メモリ開放用
          logger.debug("\n====== GC START =========")
          ObjectSpace.each_object(ActiveRecord::Relation).each(&:reset)
          GC.start
        rescue => e
          logger.debug("エラーあり")
          logger.debug(e)
          break
        end
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
        temp = Product.find_or_create_by(user:user, asin:tag)
        ecounter += 1
        temp.update(unique_id: uid, isvalid: true)

        account.update(asin_status: "実行中 " + ecounter.to_s + "件済")
        if ulevel == "trial" then
          counter += 1
          if counter > limitnum then
            break
          end
        end
      end
      #メモリ開放用
      logger.debug("\n====== GC START =========")
      ObjectSpace.each_object(ActiveRecord::Relation).each(&:reset)
      GC.start
      logger.debug(asin)
    end

    logger.debug('======= GET ASIN END =========')
    account.update(asin_status: "完了 " + ecounter.to_s + "件済")
    t = Time.now
    strTime = t.strftime("%Y年%m月%d日 %H時%M分")
    account.msend(
      "【ヤフープレミアムハンター】\nASIN取得完了しました。" + ecounter.to_s +  "件取得。\n終了時間："+strTime,
      account.cw_api_token,
      account.cw_room_id
    )

    #メモリ開放用
    logger.debug("\n====== GC START =========")
    ObjectSpace.each_object(ActiveRecord::Relation).each(&:reset)
    GC.start
    #GetItemDataJob.perform_later(current_user.email, uid)
  end
end
