# -*- coding: utf-8 -*-

require 'haml'
require 'pp'
require 'pry'
require 'sqlite3'

`mkdir -p #{ File.join(settings.root, "tmp") }`
`mkdir -p #{ File.join(settings.root, "log") }`
`mkdir -p #{ File.join(settings.root, "sim") }`

require_relative "./log.rb"
require_relative "./ngs_csv.rb"
require_relative "./task_hgmd.rb"
TaskHgmd.init_db()