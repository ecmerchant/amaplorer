class Product < ApplicationRecord

  require 'peddler'
  require 'amazon/ecs'
  require 'typhoeus'
  require 'uri'
  require 'open-uri'

  def amazon(user, uid)
    logger.debug("\n====START AMAZON DATA=======")
    #PAAPIにアクセス
    account = Account.find_by(user: user)
    account.update(yahoo_status: "準備中")
    ecounter = 0

    Amazon::Ecs.configure do |options|
      options[:AWS_access_key_id] = ENV['PA_AWS_ACCESS_KEY_ID']
      options[:AWS_secret_key] = ENV['PA_AWS_SECRET_KEY_ID']
      options[:associate_tag] = ENV['PA_ASSOCIATE_TAG']
    end

    target = Product.where(user:user, unique_id:uid)
    target.update(isvalid: true)
    orgasins = target.group(:asin).pluck(:asin)

    orgasins.each_slice(10) do |arr|
      logger.debug("\n======START=========")
      asins = arr
      logger.debug("\n\n")
      logger.debug(asins)
      logger.debug("\n\n")
      res = nil
      logger.debug("===== PAAPI =======")
      rcounter = 0
      Retryable.retryable(tries: 10, sleep: 2.0) do
        res = Amazon::Ecs.item_lookup(asins.join(','), {:IdType => 'ASIN', :country => 'jp', :ResponseGroup => 'Large'})
        rcounter += 1
        sleep(rcounter)
        logger.debug(res.error)
      end
      counter = 0
      res.items.each do |item|
        logger.debug(counter)
        asin = item.get('ASIN')
        logger.debug(asin)
        title = item.get('ItemAttributes/Title')
        logger.debug(title)
        jan = item.get('ItemAttributes/EAN')
        logger.debug(jan)
        mpn = item.get('ItemAttributes/MPN')
        logger.debug(mpn)
        image = item.get('SmallImage/URL')
        logger.debug(image)
        if image == nil || image == "" then
          logger.debug("image is nothing")
          image = item.get('ImageSets/ImageSet[@Category="primary"]/SmallImage/URL')
          if image == nil || image == "" then
            logger.debug("image is nothing 2")
            image = item.get('ImageSets/ImageSet/SmallImage/URL')
          end
        end
        temp = target.find_or_create_by(asin: asin)
        temp.update(title: title, jan: jan, mpn: mpn, amazon_image: image)
        counter += 1
      end

      #MWSにアクセス
      mp = "A1VC38T7YXB528"
      sid = account.seller_id
      auth = account.mws_auth_token
      client = MWS.products(
        primary_marketplace_id: mp,
        merchant_id: sid,
        auth_token: auth,
        aws_access_key_id: ENV['AWS_ACCESS_KEY_ID'],
        aws_secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
      )

      logger.debug("get cart data")
      logger.debug("===== CART PRICE =======")
      logger.debug(asins)
      response = client.get_competitive_pricing_for_asin(asins)
      parser = response.parse
      logger.debug(parser)

      parser.each do |product|
        logger.debug("===========")

        vvv = false
        if product.class == Array then
          logger.debug("Product is Array")
          logger.debug(product)
          ss = Hash.new
          ss['Product'] = product[1]
          product = nil
          product = ss
          logger.debug(product)
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

        temp = target.find_or_create_by(asin: asin)
        temp.update(cart_price: cartprice, cart_shipping: cartship, cart_point: cartpoint, category: category, rank: rank)
        if vvv == true then
          break
        end
      end

      logger.debug("===== LOWEST NEW =======")
      response = client.get_lowest_offer_listings_for_asin(asins,{item_condition: "New"})
      parser = response.parse

      if parser.class == Array then
        parser.each do |product|
          asin = product.dig('Product', 'Identifiers', 'MarketplaceASIN', 'ASIN')
          logger.debug("===== asin =======\n" + asin)
          buf = product.dig('Product', 'LowestOfferListings', 'LowestOfferListing')
          lowestprice = 0
          lowestship = 0
          lowestpoint = 0
          logger.debug("===== buf =======\n")
          logger.debug(buf)
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
          temp = target.find_or_create_by(asin: asin)
          ecounter += 1
          temp.update(lowest_price: lowestprice, lowest_shipping: lowestship, lowest_point: lowestpoint)
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
        logger.debug(buf)
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
        temp = target.find_or_create_by(asin: asin)
        ecounter += 1
        temp.update(lowest_price: lowestprice, lowest_shipping: lowestship, lowest_point: lowestpoint)
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
          IsAmazonFulfilled: false
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
              break
            end
          end
        end
        logger.debug("\n======FEE=========")
        logger.debug(fee)
        fee = fee.to_f / 1000
        logger.debug(fee)
        temp = target.find_or_create_by(asin: asin)
        temp.update(amazon_fee: fee)
      end
      account.update(amazon_status: "実行中 " + ecounter.to_s + "件済")
      logger.debug("\n======END=========")
    end
    account.update(amazon_status: "完了 " + ecounter.to_s + "件済")
    logger.debug("\n====END AMAZON DATA=======")
  end

  def yahoo_shopping(user, uid)
    logger.debug("\n====START YAHOO DATA=======")
    target = Product.where(user:user, unique_id:uid)
    data = target.group(:asin, :title, :jan, :mpn, :cart_price).pluck(:asin, :title, :jan, :mpn, :cart_price)
    account = Account.find_by(user: user)
    account.update(yahoo_status: "実行中")
    interval = ENV['YAHOO_INTERVAL']

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
    logger.debug(data)
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
      if query == nil then
        if mpn != nil then
          query = mpn
        else
          query = title
        end
      end
      turl = 'https://shopping.yahoo.co.jp/search?used=2&p=' + query.to_s + '&pf=' + lp.to_s
      url = URI.escape(turl)
      logger.debug(url)
      charset = nil

      ua = CSV.read('app/others/User-Agent.csv', headers: false, col_sep: "\t")
      uanum = ua.length
      user_agent = ua[rand(uanum)][0]

      sleep(interval)

      begin

        html = open(url, "User-Agent" => user_agent) do |f|
          charset = f.charset
          ss = f.status
          logger.debug("==== HTTP STATUS 1 =====")
          logger.debug(ss)
          logger.debug("======================")
          f.read # htmlを読み込んで変数htmlに渡す
        end

        #request = Typhoeus::Request.new(url, followlocation: true, headers: {"User-Agent": user_agent })
        #request.run
        #html = request.response.body

        doc = Nokogiri::HTML.parse(html, nil, charset)

        logger.debug("==== HTTP ST =====")
        logger.debug(doc.xpath('//title').inner_text)
        logger.debug("==== HTTP EN =====")

        temp = doc.xpath('//div[@class="elItemWrapper"]')[0]
        isvalid = false

        logger.debug("==== Item Hit? =====")
        #logger.debug(temp)

        if temp != nil then
          logger.debug("==== Item Found =====")
          page = temp.xpath('.//a').attribute("href").text
          yahoo_code = page.match(/jp\/([\s\S]*?)\.html/)[1]
          yahoo_code = yahoo_code.gsub("/","_")

          #request2 = Typhoeus::Request.new(page)
          #request2.run
          #html2 = request2.response.body

          user_agent = ua[rand(uanum)][0]

          html2 = open(page, "User-Agent" => user_agent) do |f|
            charset = f.charset
            ss = f.status
            logger.debug("==== HTTP STATUS 2 =====")
            logger.debug(ss)
            logger.debug("======================")
            f.read # htmlを読み込んで変数htmlに渡す
          end

          doc2 = Nokogiri::HTML.parse(html2, nil, charset)

          yahoo_price = doc2.xpath('//span[@class="elNumber"]')[0].inner_text
          yahoo_price = yahoo_price.gsub("," , "")

          if yahoo_price == nil then
            yahoo_price = 0
          end

          yahoo_shipping = doc2.xpath('//p[@class="elCost"]/em')[0].inner_text
          if yahoo_shipping == "送料無料" then
            yahoo_shipping = 0
          else
            yahoo_shipping = yahoo_shipping.gsub("送料", "")
            yahoo_shipping = yahoo_shipping.gsub("円", "")
          end

          yahoo_title = doc2.xpath('//div[@class="elTitle"]/h2')[0].inner_text
          yahoo_image = doc2.xpath('//div[@class="elMain"]//img').attribute("src").text
          yahoo_image = yahoo_image.gsub("/i/l/","/i/g/")
          normal_point = 0
          premium_point = 0
          softbank_point = 0

          buf1 = doc2.xpath('//div[@class="elList"]')
          for buf2 in buf1 do
            buf = buf2.xpath('.//dl')
            for elem in buf do
              if elem.inner_text.index('通常ポイント') != nil then
                normal_point = elem.xpath('.//span[@class="elPoint"]/text()')[0].inner_text
                normal_point = normal_point.gsub(",","")
              elsif elem.inner_text.index('プレミアム会員') != nil then
                premium_point = elem.xpath('.//span[@class="elPoint"]/text()')[0].inner_text
                premium_point = premium_point.gsub(",","")
              elsif elem.inner_text.index('ソフトバンク') != nil then
                softbank_point = elem.xpath('.//span[@class="elPoint"]/text()')[0].inner_text
                softbank_point = softbank_point.gsub(",","")
              end
            end
          end
          isvalid = true
          temp = target.find_or_create_by(asin: asin)

          if temp.cart_price != 0 then
            aprice = temp.cart_price.to_i + temp.cart_shipping.to_i
          else
            aprice = temp.lowest_price.to_i + temp.lowest_shipping.to_i
          end

          points = temp.normal_point.to_f
          if account.premium == true then
            points = points + temp.premium_point.to_f
          end
          if account.softbank == true then
            points = points + temp.softbank_point.to_f
          end

          profit = (aprice - (aprice * temp.amazon_fee.to_f) - (temp.yahoo_price.to_f - points + temp.yahoo_shipping.to_f)).to_i

          logger.debug("==== profit =====")
          logger.debug(profit)
          logger.debug("==== profit end =====")

          temp.update(isvalid: isvalid, yahoo_title: yahoo_title, yahoo_price: yahoo_price, yahoo_shipping: yahoo_shipping, yahoo_code: yahoo_code, yahoo_image: yahoo_image, normal_point: normal_point, premium_point: premium_point, softbank_point: softbank_point, profit: profit)
        else
          logger.debug("==== Item NOT Found =====")
          temp = target.find_or_create_by(asin: asin)
          yahoo_title = "該当なし"
          yahoo_price = 0
          yahoo_shipping = 0
          yahoo_code = nil
          yahoo_image = nil
          normal_point = 0
          premium_point = 0
          softbank_point = 0
          profit = 0
          temp.update(listing: false, isvalid: isvalid, yahoo_title: yahoo_title, yahoo_price: yahoo_price, yahoo_shipping: yahoo_shipping, yahoo_code: yahoo_code, yahoo_image: yahoo_image, normal_point: normal_point, premium_point: premium_point, softbank_point: softbank_point, profit: profit)
        end
      rescue => e
        logger.debug("Error!!\n")
        logger.debug(e)
      end
      counter += 1
      logger.debug("title:" + yahoo_title)
      account.update(yahoo_status: "実行中 " + counter.to_s + "件済")
    end
    logger.debug("\n====END YAHOO DATA=======")
    account.update(yahoo_status: "完了 " + counter.to_s + "件済")
  end
end
