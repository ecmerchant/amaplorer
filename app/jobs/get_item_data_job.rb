class GetItemDataJob < ApplicationJob
  queue_as :get_item_data

  rescue_from(StandardError) do |exception|
   # Do something with the exception
    logger.error exception
  end

  def perform(user, uid)
    # Do something later
    account = Account.find_by(user: user)
    account.update(amazon_status: "実行中 0%", yahoo_status: "準備中")
    a = Product.new
    a.amazon(user, uid)
    #a.yahoo_shopping(user, uid)
  end
end
