require './app'

log = File.new("log/error.log", "a+")
$stdout.reopen(log)
$stderr.reopen(log)

run EAntifonarApp
