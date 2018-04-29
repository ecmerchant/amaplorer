Resque.redis = Redis.new(:url => ENV['REDIS_URL'])

# Heroku RedisでRailsからRedisを使う場合
# $redis = Redis.new(url: ENV["REDIS_URL"])

#ActiveRecordが使えるように設定
Resque.after_fork = Proc.new { ActiveRecord::Base.establish_connection }
