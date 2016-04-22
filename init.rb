# -*- coding: utf-8 -*-
require 'haml'
require 'pp'
require 'pry'
require 'sqlite3'

config_file_path = './config.yml'
config_file config_file_path
$SETTINGS = settings

require "./log"
require "./task_manager"
require "./ngs_csv"
require "./task_hgmd"

