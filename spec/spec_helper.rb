# -*- encoding: utf-8 -*-

gem 'minitest'

require 'minitest/autorun'
require 'minitest/spec'

$:.unshift File.expand_path(File.dirname(__FILE__) + '/../lib')
require 'google_speech'
