require 'bundler/gem_tasks'
require 'rake/testtask'

desc "Default Task (test gem)"
task :default => :test

Rake::TestTask.new do |t|
  t.pattern = 'spec/**/*_spec.rb'
  t.libs.push 'spec'
end