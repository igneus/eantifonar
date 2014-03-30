require 'ostruct'
require 'log4r'
require 'log4r/yamlconfigurator'

module EAntifonar

  CONFIG = OpenStruct.new(
    :app_root => File.expand_path('.'), # by default: current working directory

    :log_config => File.join('config', 'loggers.yml'),

    :indexing_log => File.join('log', 'indexing.log'),
    :decorator_log => File.join('log', 'decorator.log'),
  )

  class << CONFIG
    def db_path
      File.expand_path('chants.sqlite3', File.join(app_root, 'db'))
    end

    def chants_path
      File.expand_path('chants', File.join(app_root, 'public'))
    end
  end

  class << self
    def init_logging
      Log4r::YamlConfigurator.load_yaml_file EAntifonar::CONFIG.log_config
    end
  end
end
