DataMapper.setup(:default, 'sqlite://' + EAntifonar::CONFIG.db_path)

%w{chant}.each do |l|
  require_relative File.join('model', l)
end

DataMapper.finalize