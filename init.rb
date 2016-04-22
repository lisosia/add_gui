# -*- coding: utf-8 -*-

require 'haml'
require 'pp'
require 'pry'
require 'sqlite3'

config_file_path = './config.yml'
config_file config_file_path
$SETTINGS = settings

`mkdir -p #{ File.join(settings.root, "tmp") }`
`mkdir -p #{ File.join(settings.root, "log") }`
`mkdir -p #{ File.join(settings.root, "sim") }`

require "./log"
require "./task_manager"
require "./ngs_csv"
require "./task_hgmd"

TaskHgmd.init_db()