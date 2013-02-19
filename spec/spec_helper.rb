# -*- encoding: utf-8 -*-

gem 'minitest'

require 'minitest/spec'
require 'minitest/autorun'

$:.unshift File.expand_path(File.dirname(__FILE__) + '/../lib')
require 'google_speech'
