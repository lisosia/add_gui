# A sample Gemfile
source "https://rubygems.org"

gem 'sinatra'
gem 'sinatra-contrib'
gem 'haml'

# thin is a webserver, thin depends on eventmachine, eventmachine v 1.2 cause error on centos5
# https://github.com/eventmachine/eventmachine/issues/709
gem 'eventmachine', '< 1.2'
gem 'thin' 

gem 'pry'
gem 'sqlite3'