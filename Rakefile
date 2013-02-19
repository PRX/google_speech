require 'bundler/gem_tasks'
require 'rake/testtask'

desc "Default Task (test gem)"
task :default => :test

Rake::TestTask.new(:test) { |t| t.test_files = FileList['test/*_test.rb'] }
