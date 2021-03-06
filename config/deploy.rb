set :application, 'eantifonar'
set :repo_url, 'https://github.com/igneus/eantifonar.git'
set :branch, 'master'

# ask :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }

# set :scm, :git

# set :format, :pretty
# set :log_level, :debug
# set :pty, true

# set :linked_files, %w{config/database.yml}
set :linked_dirs, [
  'tmp',
  'db', # where the sqlite db is stored
  'log',
  'public/chants', # scores rendered as png images
  'chantbase' # git repo of the In adiutorium project - used for automatic updates
]

# set :default_env, { path: "/opt/ruby/bin:$PATH" }
# set :keep_releases, 5

# files not taken from the git repo but unique to the server
# (symlinked from the current dir, they reside in the 'shared' dir)

namespace :deploy do

  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      # Your restart mechanism here, for example:
      execute :touch, release_path.join('tmp/restart.txt')
    end
  end

  after :restart, :clear_cache do
    on roles(:web), in: :groups, limit: 3, wait: 10 do
      # Here we can do anything such as:
      # within release_path do
      #   execute :rake, 'cache:clear'
      # end
    end
  end

  after :finishing, 'deploy:cleanup'

  after :finished, :set_current_version do
    on roles(:app) do
      # dump current git version
      within release_path do
        execute :echo, "#{capture("cd #{repo_path} && git rev-parse --short HEAD")} >> public/REVISION"
      end
    end
  end

end
