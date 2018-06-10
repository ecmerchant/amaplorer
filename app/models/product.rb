class Product < ApplicationRecord

  require 'peddler'
  require 'amazon/ecs'
  require 'typhoeus'
  require 'uri'

  def amazon(user, uid)
    logger.debug("\n====START AMAZON DATA=======")
    #PAAPIにアクセス
    Amazon::Ecs.configure do |options|
      options[:AWS_access_key_id] = ENV['PA_AWS_ACCESS_KEY_ID']
      options[:AWS_secret_key] = ENV['PA_AWS_SECRET_KEY_ID']
      options[:associate_tag] = ENV['PA_ASSOCIATE_TAG']
    end

    target = Product.where(user:user, unique_id:uid)
    orgasins = target.pluck(:asin)

    orgasins.each_slice(10) do |arr|
      logger.debug("\n======START=========")
      asins = arr
      logger.debug("\n\n")
      logger.debug(asins)
      logger.debug("\n\n")
      res = nil
      Retryable.retryable(tries: 5, sleep: 1.5) do
        res = Amazon::Ecs.item_lookup(asins.join(','), {:IdType => 'ASIN', :country => 'jp', :ResponseGroup => 'Large'})
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
        image = item.get('LargeImage/URL')
        logger.debug(image)
        temp = target.find_by(asin: asin)
        temp.update(title: title, jan: jan, mpn: mpn, amazon_image: image)
        counter += 1
      end

      #MWSにアクセス
      mp = "A1VC38T7YXB528"
      temp = Account.find_by(user: user)
      sid = temp.seller_id
      auth = temp.mws_auth_token
      client = MWS.products(
        primary_marketplace_id: mp,
        merchant_id: sid,
        auth_token: auth,
        aws_access_key_id: ENV['AWS_ACCESS_KEY_ID'],
        aws_secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
      )

      logger.debug("get cart data")
      response = client.get_competitive_pricing_for_asin(asins)
      parser = response.parse

      parser.each do |product|
        asin = product.dig('Product', 'Identifiers', 'MarketplaceASIN', 'ASIN')
        cartprice = product.dig('Product', 'CompetitivePricing', 'CompetitivePrices','CompetitivePrice' ,'Price', 'ListingPrice','Amount')
        cartship = product.dig('Product', 'CompetitivePricing', 'CompetitivePrices','CompetitivePrice' , 'Price', 'Shipping','Amount')
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
        if salesrank != nil then
          category = salesrank.last.dig('ProductCategoryId')
          rank = salesrank.last.dig('Rank')
        else
          category = nil
          rank = nil
        end
        temp = target.find_by(asin: asin)
        temp.update(cart_price: cartprice, cart_shipping: cartship, cart_point: cartpoint, category: category, rank: rank)
      end

      response = client.get_lowest_offer_listings_for_asin(asins,{item_condition: "New"})
      parser = response.parse

      parser.each do |product|
        asin = product.dig('Product', 'Identifiers', 'MarketplaceASIN', 'ASIN')
        buf = product.dig('Product', 'LowestOfferListings', 'LowestOfferListing')
        lowestprice = 0
        lowestship = 0
        lowestpoint = 0
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
        temp = target.find_by(asin: asin)
        temp.update(amazon_fee: fee)
      end
      logger.debug("\n======END=========")
    end
    logger.debug("\n====END AMAZON DATA=======")
  end

  def yahoo_shopping(user, uid)
    logger.debug("\n====START YAHOO DATA=======")
    target = Product.where(user:user, unique_id:uid)
    data = target.pluck(:asin, :title, :jan, :mpn)
    logger.debug(data)
    for var in data do

      asin = var[0]
      title = var[1]
      jan = var[2]
      mpn = var[3]
      logger.debug(asin)

      query = jan
      if query == nil then
        if mpn != nil then
          query = mpn
        else
          query = title
        end
      end
      turl = 'https://shopping.yahoo.co.jp/search?used=2&p=' + query.to_s
      url = URI.escape(turl)
      logger.debug(url)
      charset = nil

      ua = CSV.read('app/others/User-Agent.csv', headers: false, col_sep: "\t")
      uanum = ua.length
      user_agent = ua[rand(uanum)][0]

      sleep(0.5)

      begin
        request = Typhoeus::Request.new(url, followlocation: true, headers: {"User-Agent": user_agent })
        request.run
        html = request.response.body
        doc = Nokogiri::HTML.parse(html, nil, charset)
        temp = doc.xpath('//div[@class="elItemWrapper"]')[0]
        isvalid = false
        
        if temp != nil then

          page = temp.xpath('.//a').attribute("href").text
          yahoo_code = page.match(/jp\/([\s\S]*?)\.html/)[1]
          yahoo_code = yahoo_code.gsub("/","_")

          request2 = Typhoeus::Request.new(page)
          request2.run
          html2 = request2.response.body
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
          temp = target.find_by(asin: asin)
          temp.update(isvalid: isvalid, yahoo_title: yahoo_title, yahoo_price: yahoo_price, yahoo_shipping: yahoo_shipping, yahoo_code: yahoo_code, yahoo_image: yahoo_image, normal_point: normal_point, premium_point: premium_point, softbank_point: softbank_point)
        else
          temp = target.find_by(asin: asin)
          yahoo_title = "該当なし"
          temp.update(isvalid: isvalid, yahoo_title: yahoo_title)
        end
      rescue => e
        logger.debug("Error!!\n")
        logger.debug(e)
      end
    end
    logger.debug("\n====END YAHOO DATA=======")
  end

end
