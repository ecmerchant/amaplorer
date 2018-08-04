interval = ENV['PWK_INTERVAL']
if interval == nil then
  interval = 1
end
PumaWorkerKiller.enable_rolling_restart(interval * 3600) # 8 hours in seconds
