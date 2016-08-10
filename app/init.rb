# -*- coding: utf-8 -*-

require 'haml'
require 'pp'
require 'pry'
require 'sqlite3'

`mkdir -p #{ File.join(settings.root, "tmp") }`
`mkdir -p #{ File.join(settings.root, "log") }`
`mkdir -p #{ File.join(settings.root, "sim") }`

`mkdir -p tmp`

require_relative "./log.rb"
include MyLog
require_relative "./ngs_csv.rb"
require_relative "./task_hgmd.rb"
TaskHgmd.init_db()

require_relative './ps_wrap.rb'
