require 'csv'

CSV.generate do |csv|
  column_names = %w(ASIN アマゾン商品名 ヤフーショッピング商品名 アマゾン価格 ヤフーショッピング価格 利益額 アマゾンリンク ヤフーショッピングリンク)
  csv << column_names
  pp = @account.premium
  ss = @account.softbank
  @products.each do |product|

    if product.cart_price != 0 then
      aprice = product.cart_price.to_f + product.cart_shipping.to_f
    else
      aprice = product.lowest_price.to_f + product.lowest_shipping.to_f
    end

    points = product.normal_point.to_f
    if pp == true then
      points = points + product.premium_point.to_f
    end
    if ss == true then
      points = points + product.softbank_point.to_f
    end

    if (product.yahoo_price.to_f - points) != 0 then
      profit = (aprice - (aprice * product.amazon_fee.to_f) - (product.yahoo_price.to_f - points + product.yahoo_shipping.to_f)).to_i
    else
      profit = 0
    end

    amazon_url = "https://www.amazon.co.jp/dp/" + product.asin.to_s

    column_values = [
      product.asin,
      product.title,
      product.yahoo_title,
      aprice,
      product.yahoo_price.to_i,
      profit,
      amazon_url,
      product.yahoo_url
    ]
    csv << column_values
  end
end
