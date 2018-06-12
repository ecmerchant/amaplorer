class GetItemDataJob < ApplicationJob
  queue_as :default

  rescue_from(StandardError) do |exception|
   # Do something with the exception
    logger.error exception
  end
  
  def perform(user, uid)
    # Do something later
    a = Product.new
    a.amazon(user, uid)
    a.yahoo_shopping(user, uid)
  end
end
