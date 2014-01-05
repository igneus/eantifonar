require './app'

log = File.new("log/error.log", "a+")
$stderr.reopen(log)

run EAntifonarApp
