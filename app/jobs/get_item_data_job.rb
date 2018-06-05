class GetItemDataJob < ApplicationJob
  queue_as :default

  def perform(user, uid)
    # Do something later
    a = Product.new
    a.amazon(user, uid)
    a.yahoo_shopping(user, uid)
  end
end
