$coffee = []

Dir['public/js/*.coffee'].each do |c|
  o = c.sub('.coffee', '.js')
  $coffee << o

  file o => [c] do
    sh "coffee -c #{c}"
  end
end

task :coffee => $coffee

task :default => [:coffee]
