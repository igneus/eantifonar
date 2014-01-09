require 'ostruct'

module EAntifonar

  CONFIG = OpenStruct.new(
    :app_root => File.expand_path('.'), # by default: current working directory

    :indexing_log => File.join('log', 'indexing.log')
  )

  class << CONFIG
    def db_path
      File.expand_path('chants.sqlite3', File.join(app_root, 'db'))
    end

    def chants_path
      File.expand_path('chants', File.join(app_root, 'public'))
    end
  end
end
