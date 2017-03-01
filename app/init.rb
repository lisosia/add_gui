# -*- coding: utf-8 -*-

require 'haml'
require 'pp'
require 'pry'
require 'sqlite3'
require 'fileutils'

FileUtils.mkdir_p File.join(settings.root, "tmp")
FileUtils.mkdir_p File.join(settings.root, "log")
FileUtils.mkdir_p File.join(settings.root, "sim")
