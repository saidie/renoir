$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'renoir'

require 'yaml'
require 'minitest/autorun'

CONFIG = YAML.load(open(File.expand_path('../config.yml', __FILE__)))
