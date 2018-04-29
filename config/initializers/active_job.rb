#ActiveJob用のイニシャライザを作成,アダプタにResqueを指定
ActiveJob::Base.queue_adapter = :resque
