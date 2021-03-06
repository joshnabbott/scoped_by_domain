require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "scoped_by_domain"
    gem.summary = %Q{Gem provides domain-scoping capability to your model attributes.}
    gem.description = %Q{Use this gem to scope active record attribute values by specific domains. EG: is_active returns `true` at oakley.com, but `false` at oakley.ca.}
    gem.email = "joshnabbott@gmail.com"
    gem.homepage = "http://github.com/joshnabbott/scoped_by_domain"
    gem.authors = ["Josh N. Abbott"]
    gem.add_development_dependency "rspec"
    gem.add_runtime_dependency 'activerecord', '>= 2.3.4'
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: sudo gem install jeweler"
end

require 'spec/rake/spectask'
Spec::Rake::SpecTask.new(:spec) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.spec_files = FileList['spec/**/*_spec.rb']
end

Spec::Rake::SpecTask.new(:rcov) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rcov = true
end

task :spec => :check_dependencies

task :default => :spec

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  if File.exist?('VERSION')
    version = File.read('VERSION')
  else
    version = ""
  end

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "scoped_by_domain #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
