class Product < ApplicationRecord

  require 'peddler'
  require 'amazon/ecs'
  require 'typhoeus'
  require 'uri'
  require 'open-uri'
  require 'vacuum'

  def amazon(user, uid)
    logger.debug("\n====START AMAZON DATA=======")
    #PAAPIにアクセス
    account = Account.find_by(user: user)
    account.update(yahoo_status: "準備中")
    account.update(amazon_status: "実行中 0%")
    ecounter = 0

    t = Time.now
    strTime = t.strftime("%Y年%m月%d日 %H時%M分")
    if account.cw_api_token.present? then
      account.msend(
        "【ヤフープレミアムハンター】\nアマゾン取得開始しました。\n開始時間："+strTime,
        account.cw_api_token,
        account.cw_room_id
      )
    end

    begin
      logger.debug("\n====== begin =======")

      target = Product.where(user:user, unique_id:uid)
      orgasins = target.group(:asin).pluck(:asin)
      maxnum = orgasins.length

      orgasins.each_slice(10) do |asins|
        logger.debug("\n====== PAAPI START =========")
        logger.debug(asins)
        rcounter = 0
        response = nil

        request = Vacuum.new(marketplace: 'JP',
                       access_key: ENV['PA_AWS_ACCESS_KEY_ID'],
                       secret_key: ENV['PA_AWS_SECRET_KEY_ID'],
                       partner_tag: ENV['PA_ASSOCIATE_TAG'])

        Retryable.retryable(tries: 5, sleep: 1.0) do |retries, exception|
          response = request.get_items(
            item_ids: asins,
            resources: ['Images.Primary.Medium', 'ItemInfo.Title', 'ItemInfo.ExternalIds', 'ItemInfo.ManufactureInfo']
          )
          logger.debug(retries)
          sleep(retries)
          puts "try #{retries} failed with exception: #{exception}" if retries > 0
        end


        counter = 0
        result_items = response.to_h.dig('ItemsResult', 'Items')
        logger.debug(result_items)

        logger.debug(1)

        if result_items.class == Array then
          logger.debug(2)
          result_items.each do |item|
            logger.debug(3)
            asin = item.dig('ASIN')
            detail_url = item.dig('DetailPageURL')
            title = item.dig('ItemInfo', 'Title', 'DisplayValue')
            jan = item.dig('ItemInfo', 'ExternalIds', 'EANs', 'DisplayValues', 0)
            mpn = item.dig('ItemInfo', 'ManufactureInfo', 'ItemPartNumber', 'DisplayValues')
            image = item.dig('Images', 'Primary', 'Medium', 'URL')

            logger.debug("------------------------------------")
            logger.debug("asin: " + asin.to_s)
            logger.debug("title: " + title.to_s)
            logger.debug("jan: " + jan.to_s)
            logger.debug("mpn: " + mpn.to_s)
            logger.debug("image: " + image.to_s)
            logger.debug("detail_url: " + detail_url.to_s)

            temp = target.find_by(asin: asin)
            if temp != nil then
              temp.update(title: title, jan: jan, mpn: mpn, amazon_image: image, amazon_url: detail_url)
              counter += 1
            end

          end
        else
          logger.debug(4)
          item = result_items
          asin = item.dig('ASIN')
          title = item.dig('Title', 'DisplayValue')
          jan = item.dig('ItemInfo', 'ExternalIds', 'EANs', 'DisplayValues', 0)
          mpn = item.dig('ManufactureInfo', 'ItemPartNumber', 'DisplayValues')
          image = item.dig('Images', 'Primary', 'Medium', 'URL')

          logger.debug("------------------------------------")
          logger.debug("asin: " + asin.to_s)
          logger.debug("title: " + title.to_s)
          logger.debug("jan: " + jan.to_s)
          logger.debug("mpn: " + mpn.to_s)
          logger.debug("image: " + image.to_s)

          temp = target.find_by(asin: asin)
          if temp != nil then
            temp.update(title: title, jan: jan, mpn: mpn, amazon_image: image, amazon_url: detail_url)
            counter += 1
          end
        end

        #MWSにアクセス
        mp = "A1VC38T7YXB528"
        sid = account.seller_id.to_s.strip
        auth = account.mws_auth_token.to_s.strip
        client = MWS.products(
          marketplace: mp,
          merchant_id: sid,
          auth_token: auth,
          aws_access_key_id: ENV['AWS_ACCESS_KEY_ID'],
          aws_secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
        )

        logger.debug("get cart data")
        logger.debug("===== CART PRICE =======")
        logger.debug(asins)
        response = client.get_competitive_pricing_for_asin(mp, asins)
        parser = response.parse
        #logger.debug(parser)

        parser.each do |product|
          logger.debug("===========")

          vvv = false
          if product.class == Array then
            logger.debug("Product is Array")
            #logger.debug(product)
            ss = Hash.new
            ss['Product'] = product[1]
            product = nil
            product = ss
            #logger.debug(product)
            vvv = true
          end

          asin = product.dig('Product', 'Identifiers', 'MarketplaceASIN', 'ASIN')
          logger.debug("===== cart price ====")
          cartprice = product.dig('Product', 'CompetitivePricing', 'CompetitivePrices','CompetitivePrice' ,'Price', 'ListingPrice','Amount')
          logger.debug("===== cart ship ====")
          cartship = product.dig('Product', 'CompetitivePricing', 'CompetitivePrices','CompetitivePrice' , 'Price', 'Shipping','Amount')
          logger.debug("===== cart point ====")
          cartpoint = product.dig('Product', 'CompetitivePricing', 'CompetitivePrices','CompetitivePrice' , 'Price', 'Points','PointsNumber')
          if cartprice == nil then
            cartprice = 0
          end
          if cartship == nil then
            cartship = 0
          end
          if cartpoint == nil then
            cartpoint = 0
          end
          salesrank = product.dig('Product', 'SalesRankings', 'SalesRank')
          logger.debug("===== sales rank ====")
          if salesrank != nil then
            if salesrank.class == Array then
              category = salesrank.last.dig('ProductCategoryId')
              rank = salesrank.last.dig('Rank')
            else
              category = salesrank.dig('ProductCategoryId')
              rank = salesrank.dig('Rank')
            end
          else
            category = nil
            rank = nil
          end

          temp = target.find_by(asin: asin)
          if temp != nil then
            temp.update(cart_price: cartprice, cart_shipping: cartship, cart_point: cartpoint, category: category, rank: rank)
          end
          if vvv == true then
            break
          end
        end

        logger.debug("===== LOWEST NEW =======")
        response = client.get_lowest_offer_listings_for_asin(mp, asins, {item_condition: "New"})
        parser = response.parse

        if parser.class == Array then
          parser.each do |product|
            asin = product.dig('Product', 'Identifiers', 'MarketplaceASIN', 'ASIN')
            logger.debug("===== asin =======\n" + asin.to_s)
            buf = product.dig('Product', 'LowestOfferListings', 'LowestOfferListing')
            lowestprice = 0
            lowestship = 0
            lowestpoint = 0
            logger.debug("===== buf =======\n")
            #logger.debug(buf)
            if buf != nil then
              logger.debug(buf.length)
              lowestprice = product.dig('Product', 'LowestOfferListings', 'LowestOfferListing', 0, 'Price', 'ListingPrice','Amount')
              lowestship = product.dig('Product', 'LowestOfferListings', 'LowestOfferListing', 0,'Price', 'Shipping','Amount')
              lowestpoint = product.dig('Product', 'LowestOfferListings', 'LowestOfferListing', 0, 'Price', 'Points','PointsNumber')
              if lowestpoint == nil then
                lowestpoint = 0
              end
              if lowestship == nil then
                lowestship = 0
              end
              if lowestprice == nil then
                lowestprice = 0
              end
            else
              lowestprice = 0
              lowestship = 0
              lowestpoint = 0
            end
            temp = target.find_by(asin: asin)
            ecounter += 1
            if temp != nil then
              temp.update(lowest_price: lowestprice, lowest_shipping: lowestship, lowest_point: lowestpoint)
            end
          end
        else
          logger.debug("===== ONE ASIN =======\n")
          asin = parser.dig('Product', 'Identifiers', 'MarketplaceASIN', 'ASIN')
          logger.debug("===== asin =======\n" + asin)
          buf = parser.dig('Product', 'LowestOfferListings', 'LowestOfferListing')
          lowestprice = 0
          lowestship = 0
          lowestpoint = 0
          logger.debug("===== buf =======\n")
          #logger.debug(buf)
          if buf != nil then
            logger.debug(buf.length)
            lowestprice = parser.dig('Product', 'LowestOfferListings', 'LowestOfferListing', 0, 'Price', 'ListingPrice','Amount')
            lowestship = parser.dig('Product', 'LowestOfferListings', 'LowestOfferListing', 0,'Price', 'Shipping','Amount')
            lowestpoint = parser.dig('Product', 'LowestOfferListings', 'LowestOfferListing', 0, 'Price', 'Points','PointsNumber')
            if lowestpoint == nil then
              lowestpoint = 0
            end
            if lowestship == nil then
              lowestship = 0
            end
            if lowestprice == nil then
              lowestprice = 0
            end
          else
            lowestprice = 0
            lowestship = 0
            lowestpoint = 0
          end
          temp = target.find_by(asin: asin)
          ecounter += 1
          if temp != nil then
            temp.update(lowest_price: lowestprice, lowest_shipping: lowestship, lowest_point: lowestpoint)
          end
        end

        requests = []
        i = 0

        asins.each do |asin|
          prices = {
            ListingPrice: { Amount: 1000, CurrencyCode: "JPY", }
          }
          request = {
            MarketplaceId: "A1VC38T7YXB528",
            IdType: "ASIN",
            IdValue: asin,
            PriceToEstimateFees: prices,
            Identifier: "req" + i.to_s,
            IsAmazonFulfilled: true
          }
          requests[i] = request
          i += 1
        end

        logger.debug("===== FEES ESTIMATE =======")
        response = client.get_my_fees_estimate(requests)
        parser = response.parse

        doc2 = Nokogiri::XML(response.body)
        doc2.remove_namespaces!

        asins.each do |asin|
          fee = 0
          temp2 = doc2.xpath("//FeesEstimateResult")

          for tt in temp2
            casin = tt.xpath("FeesEstimateIdentifier/IdValue")[0].text
            if casin == asin then
              tfee = tt.xpath("FeesEstimate/FeeDetailList/FeeDetail/FeeAmount/Amount")[0]
              if tfee != nil then
                fee = tfee.text
                totalfee = tt.xpath("FeesEstimate/TotalFeesEstimate/Amount")
                if totalfee != nil then
                  totalfee = totalfee.text
                  logger.debug(totalfee)
                end
                break
              end
            end
          end
          logger.debug("\n======FEE=========")

          fbafee = totalfee.to_i - fee.to_i
          fee = fee.to_f / 1000
          logger.debug(fee)
          logger.debug(fbafee)
          if fee == 0 then
            fee = 0.15
          end
          if fba_fee == 0 then
            fbafee = 500
          end

          temp = target.find_by(asin: asin)
          if temp != nil then
            if temp.cart_price.to_i == 0 && temp.lowest_price.to_i == 0 then
              fee = 0
              fbafee = 0
            end
            temp.update(amazon_fee: fee, fba_fee: fbafee)
          end
        end
        account.update(amazon_status: "実行中 " + ((ecounter.to_f / maxnum.to_f)*100).round.to_s + "%")
        logger.debug(ecounter.to_i)
        logger.debug("実行中 " + ((ecounter.to_i / maxnum.to_i)*100).round.to_s + "%")
        #メモリ開放用
        logger.debug("\n====== GC START =========")
        ObjectSpace.each_object(ActiveRecord::Relation).each(&:reset)
        GC.start
        logger.debug("\n======END=========")
      end
    rescue => e
      logger.debug(e)
      t = Time.now
      strTime = t.strftime("%Y年%m月%d日 %H時%M分")
      if account.cw_api_token.present? then
        account.msend(
          "【ヤフープレミアムハンター】\nアマゾン取得エラー!!\nエラー内容:" + e.to_s + "\nエラー箇所：" + e.backtrace[0].to_s + "\nユーザ：" + user.to_s + "\nユニークID:" + uid.to_s + "\n発生時間:" + strTime,
          ENV['ADMIN_CW_API_TOKEN'],
          ENV['ADMIN_CW_ROOM_ID']
        )
      end
    end

    account.update(amazon_status: "完了")

    t = Time.now
    strTime = t.strftime("%Y年%m月%d日 %H時%M分")

    if account.cw_api_token.present? then
      account.msend(
        "【ヤフープレミアムハンター】\nアマゾン取得終了しました。\n終了時間："+strTime,
        account.cw_api_token,
        account.cw_room_id
      )
    end
    logger.debug("\n====END AMAZON DATA=======")
  end



  def yahoo_shopping(user, uid)
    cc = 0
    upto = 3
    logger.debug("\n====START YAHOO DATA=======")
    target = Product.where(user:user, unique_id:uid)
    data = target.group(:asin, :title, :jan, :mpn, :cart_price).pluck(:asin, :title, :jan, :mpn, :cart_price)
    ua = CSV.read('app/others/User-Agent.csv', headers: false, col_sep: "\t")
    uanum = ua.length
    affiliate = "http%3A%2F%2Fck.jp.ap.valuecommerce.com%2Fservlet%2Freferral%3Fsid%3D3143367%26pid%3D883269369%26vc_url%3D"

    maxnum = data.length
    account = Account.find_by(user: user)
    account.update(yahoo_status: "実行中 0%")
    yaid1 = ENV['YAHOO_APPID']
    yaid2 = ENV['YAHOO_APPID2']
    yaid3 = ENV['YAHOO_APPID3']

    premium_times = ENV['PREMIUM_TIMES']
    if premium_times == nil then
      premium_times = 0.05
    end

    if yaid2 == nil then
      yaid2 = yaid1
    end

    if yaid3 == nil then
      yaid3 = yaid1
    end

    yaids = [yaid1, yaid2, yaid3]

    #yahoo_appid = ENV['YAHOO_APPID']
    yahoo_appid = yaids.sample
    account.update(yahoo_status: "実行中")
    interval = ENV['YAHOO_INTERVAL']
    skip = ENV['GC_INTERVAL']
    ecounter = 0
    if skip == nil then
      skip = 5
    end
    logger.debug(skip)
    #endpoint = 'https://shopping.yahooapis.jp/ShoppingWebService/V1/itemSearch?appid=' + yahoo_appid.to_s + '&affiliate_type=vc&affiliate_id=' + affiliate + '&condition=new&availability=1'
    endpoint = 'https://shopping.yahooapis.jp/ShoppingWebService/V3/itemSearch?appid=' + yahoo_appid.to_s + '&affiliate_type=vc&affiliate_id=' + affiliate + '&condition=new&in_stock=true'

    cand = 0
    dd = 0
    t = Time.now
    strTime = t.strftime("%Y年%m月%d日 %H時%M分")
    account.msend(
      "【ヤフープレミアムハンター】\nヤフーショッピング取得開始しました。\n開始時間："+strTime,
      account.cw_api_token,
      account.cw_room_id
    )

    if interval != nil then
      interval = interval.to_f
    else
      interval = 1.0
    end

    lb = ENV['LOWEST_PRICE']
    if lb == nil then
      lb = 0.10
    else
      lb = lb.to_f
    end
    #logger.debug(data)
    counter = 0
    for var in data do

      asin = var[0]
      title = var[1]
      jan = var[2]
      mpn = var[3]
      cprice = var[4]
      if cprice == nil then
        cprice = 0
      end
      lp = (cprice * lb).round
      logger.debug(asin)

      query = jan
      url = endpoint + '&jan_code=' + query.to_s + '&price_from=' + lp.to_s

      if query == nil then
        if mpn != nil then
          query = mpn
          query = URI.escape(query)
          url = endpoint + '&query=' + query.to_s + '&price_from=' + lp.to_s
        else
          query = title
          if query != nil then
            query = URI.escape(query)
            url = endpoint + '&query=' + query.to_s + '&price_from=' + lp.to_s
          else
            url = endpoint + '&query=' + query.to_s + '&price_from=' + lp.to_s
          end
        end
      end
      logger.debug("====Y query=====")
      logger.debug(query)
      logger.debug("=========")
      logger.debug(url)
      charset = nil

      if query != nil then
        logger.debug("== query found ==")
        user_agent = ua.sample[0]
        sleep(interval)
        cc = 0
        begin
          logger.debug("== access ==")
          html = open(url, "User-Agent" => user_agent) do |f|
            charset = f.charset
            ss = f.status
            logger.debug("==== HTTP STATUS 1 =====")
            logger.debug(ss)
            logger.debug("======================")
            f.read # htmlを読み込んで変数htmlに渡す
          end

          doc = JSON.parse(html)
          temp = doc["hits"]
          isvalid = false
          logger.debug("==== Item Hit? =====")
          if temp.first != nil then
            logger.debug("==== Item Found =====")
            buf = temp.first
            page = buf["url"]
            yahoo_code = buf["code"]
            yahoo_price = buf["price"]
            yahoo_shipping = buf["shipping"]["code"]

            if yahoo_shipping.to_i == 2 || yahoo_shipping.to_i == 3  then
              yahoo_shipping = 0
            else
              yahoo_shipping = buf["shipping"]["name"]
              yahoo_shipping = yahoo_shipping.match(/送料([\s\S]*?)円/)
              if yahoo_shipping != nil then
                yahoo_shipping = yahoo_shipping.match(/送料([\s\S]*?)円/)[1]
                yahoo_shipping = yahoo_shipping.gsub(",","")
              else
                yahoo_shipping = 0
              end
            end

            yahoo_title = buf["name"]
            yahoo_image = buf["image"]["small"]

            normal_point = 0
            premium_point = 0
            softbank_point = 0

            normal_point = buf["point"]["amount"]

            if ENV['PREMIUM_TIMES'] == nil then
              premium_point = buf["point"]["premiumAmount"]
            else
              premium_point = (yahoo_price.to_f * premium_times.to_f).round
            end

            softbank_point = (yahoo_price.to_f * 0.05).round

            logger.debug("=== Points ====")
            logger.debug(normal_point)
            logger.debug(premium_point)
            logger.debug(softbank_point)


            isvalid = true
            temp = target.find_by(asin: asin)

            if temp.cart_price != 0 then
              aprice = temp.cart_price.to_i + temp.cart_shipping.to_i
            else
              aprice = temp.lowest_price.to_i + temp.lowest_shipping.to_i
            end

            points = normal_point.to_f
            if account.premium == true then
              points = points + premium_point.to_f
            end
            if account.softbank == true then
              points = points + softbank_point.to_f
            end

            logger.debug("==== profit Calc =====")
            logger.debug(profit)
            logger.debug("==== profit Calc end =====")

            profit = (aprice - (aprice * temp.amazon_fee.to_f) - (yahoo_price.to_f - points + yahoo_shipping.to_f) - temp.fba_fee.to_f).to_i

            logger.debug("==== profit =====")
            logger.debug(profit)
            logger.debug("==== profit end =====")

            if profit > 0 then
              cand += 1
            end
            if temp != nil then
              temp.update(isvalid: isvalid, yahoo_title: yahoo_title, yahoo_url: page, yahoo_price: yahoo_price, yahoo_shipping: yahoo_shipping, yahoo_code: yahoo_code, yahoo_image: yahoo_image, normal_point: normal_point, premium_point: premium_point, softbank_point: softbank_point, profit: profit)
            end
          else
            logger.debug("==== Item NOT Found =====")
            temp = target.find_by(asin: asin)
            yahoo_title = "該当なし"
            page = ""
            yahoo_price = 0
            yahoo_shipping = 0
            yahoo_code = nil
            yahoo_image = nil
            normal_point = 0
            premium_point = 0
            softbank_point = 0
            profit = 0
            if temp != nil then
              temp.update(listing: false, isvalid: isvalid, yahoo_title: yahoo_title, yahoo_url: page, yahoo_price: yahoo_price, yahoo_shipping: yahoo_shipping, yahoo_code: yahoo_code, yahoo_image: yahoo_image, normal_point: normal_point, premium_point: premium_point, softbank_point: softbank_point, profit: profit)
            end
          end

        rescue => e
          logger.debug("Error!!\n")
          logger.debug(e)
          cc += 1
          retry if cc < upto
          next
          #logger.debug(ENV['ADMIN_CW_API_TOKEN'])
          #logger.debug(ENV['ADMIN_CW_ROOM_ID'])
          t = Time.now
          strTime = t.strftime("%Y年%m月%d日 %H時%M分")
          account.msend(
            "【ヤフープレミアムハンター】\nヤフーショッピング エラー!!\nエラー内容:" + e.to_s + "\nエラー箇所：" + e.backtrace[0].to_s + "\nユーザ：" + user.to_s + "\nユニークID:" + uid.to_s + "\nASIN:" + asin.to_s + "\n発生時間:" + strTime,
            ENV['ADMIN_CW_API_TOKEN'],
            ENV['ADMIN_CW_ROOM_ID']
          )
          logger.debug("==== Item Error =====")
          temp = target.find_by(asin: asin)
          yahoo_title = "商品情報なし"
          yahoo_price = 0
          yahoo_shipping = 0
          page = ""
          yahoo_code = nil
          yahoo_image = nil
          normal_point = 0
          premium_point = 0
          softbank_point = 0
          profit = 0
          if temp != nil then
            temp.update(listing: false, isvalid: isvalid, yahoo_title: yahoo_title, yahoo_url: page, yahoo_price: yahoo_price, yahoo_shipping: yahoo_shipping, yahoo_code: yahoo_code, yahoo_image: yahoo_image, normal_point: normal_point, premium_point: premium_point, softbank_point: softbank_point, profit: profit)
          end
        end
      else
        logger.debug("==== Item NO QUERY =====")
        temp = target.find_by(asin: asin)
        yahoo_title = "商品情報なし"
        yahoo_price = 0
        yahoo_shipping = 0
        page = ""
        yahoo_code = nil
        yahoo_image = nil
        normal_point = 0
        premium_point = 0
        softbank_point = 0
        profit = 0
        if temp != nil then
          temp.update(listing: false, isvalid: isvalid, yahoo_title: yahoo_title, yahoo_url: page, yahoo_price: yahoo_price, yahoo_shipping: yahoo_shipping, yahoo_code: yahoo_code, yahoo_image: yahoo_image, normal_point: normal_point, premium_point: premium_point, softbank_point: softbank_point, profit: profit)
        end
      end
      counter += 1
      ecounter += 1
      logger.debug("title:" + yahoo_title)
      logger.debug("実行中 " + ((counter.to_f / maxnum.to_f)*100).round.to_s + "%")
      account.update(yahoo_status: "実行中 " + ((counter.to_f / maxnum.to_f)*100).round.to_s + "%")
      if ecounter == skip then
        #メモリ開放用
        logger.debug("\n====== GC START =========")
        ObjectSpace.each_object(ActiveRecord::Relation).each(&:reset)
        GC.start
        ecounter = 0
      end
    end

    logger.debug("\n====END YAHOO DATA=======")
    account.update(yahoo_status: "完了")
    t = Time.now
    strTime = t.strftime("%Y年%m月%d日 %H時%M分")
    account.msend(
      "【ヤフープレミアムハンター】\nヤフーショッピング取得終了しました。\n終了時間："+strTime+"\n候補商品 約" + cand.to_s + "件ヒット。\n検索URL: " + account.amazon_url + "\n===================================",
      account.cw_api_token,
      account.cw_room_id
    )

    #メモリ開放用
    logger.debug("\n====== GC START =========")
    ObjectSpace.each_object(ActiveRecord::Relation).each(&:reset)
    GC.start

  end
end
