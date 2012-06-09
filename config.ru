$: << File.join(File.dirname(__FILE__), "lib")

require 'bundler/setup'

require 'mcorpc'

set :run, false

run MCORPC::WebApp.new

