# encoding: utf-8

require 'rspec/core/rake_task'
require 'jettywrapper'

JETTY_HOME = File.expand_path(File.dirname(__FILE__) + '/../../spec/jetty')
SOLR_HOME = File.expand_path(JETTY_HOME + '/solr')
SOLR_DATA_DIR = File.expand_path(SOLR_HOME + '/data')

JETTY_PARAMS = {
  :jetty_home => JETTY_HOME,
  :jetty_port => 8983,
  :solr_home => SOLR_HOME,
  # :solr_data_dir => SOLR_DATA_DIR
  :java_opts => "-Dsolr.data.dir=#{SOLR_DATA_DIR}",
  :startup_wait => 20
}

desc "integration tests"
task :integration do
  jetty_setup
  error = Jettywrapper.wrap(JETTY_PARAMS) do  
    Rake::Task["spec"].invoke
  end
  raise "test failures: #{error}" if error
end

desc "Start jetty"
task :start do
  jetty_setup
  Jettywrapper.start(JETTY_PARAMS)
  puts "jetty started at PID #{Jettywrapper.pid(JETTY_PARAMS)}"
end
  
desc "stop jetty"
task :stop do
  Jettywrapper.stop(JETTY_PARAMS)
  puts "jetty stopped"
end

# The tests require a dist_site build of solrmarc-sw
# This checks solrmarc-sw out as a submodule and runs the ant build 
# before running the tests
RSpec::Core::RakeTask.new(:rspec) do |spec|  
  spec.rspec_opts = ["--tag ~integration", "-c", "-f progress", "-r ./spec/spec_helper.rb"]
end

def jetty_setup
  puts "setting up jetty"
  `git submodule init; git submodule update`
  Dir.chdir(Dir.pwd + "/solrmarc-sw") do
      `ant dist_site`
  end
  logs_dir = JETTY_HOME + '/logs'
  Dir::mkdir(logs_dir) unless File.exists?(logs_dir)
  
  webapps_dir = JETTY_HOME + '/webapps'
  Dir::mkdir(webapps_dir) unless File.exists?(webapps_dir)
  solr_war = JETTY_HOME + '/../solr/war/apache-solr-3.6-2012-03-12_06-37-07.war'
  # copy solr.war file to webapps_dir
  FileUtils.cp solr_war, "#{webapps_dir}/solr.war"
  
  # Make solr directories
  solr_home = JETTY_PARAMS[:solr_home]
  solr_conf = solr_home + '/conf'
  solr_data = solr_home + '/data'
  solr_lib = solr_home + '/lib'
  Dir::mkdir(solr_home) unless File.exists?(solr_home)
  Dir::mkdir(solr_conf) unless File.exists?(solr_conf)
  Dir::mkdir(solr_data) unless File.exists?(solr_data)
  Dir::mkdir(solr_lib) unless File.exists?(solr_lib)
  
  # copy solr config files
  searchworks_solrconfig = STANFORD_SW + '/solr/conf/solrconfig-no-repl.xml'
  # searchworks_schema = STANFORD_SW + '/solr/conf/schema.xml'
  searchworks_schema = File.expand_path(File.dirname(__FILE__) + '/../../config/solr/schema.xml')
  searchworks_stopwords = STANFORD_SW + '/solr/conf/stopwords_punctuation.txt'
  FileUtils.cp searchworks_solrconfig, "#{solr_conf}/solrconfig.xml"
  FileUtils.cp searchworks_schema, solr_conf
  FileUtils.cp searchworks_stopwords, solr_conf
  
  
  # copy solr lib files
  searchworks_lib_dir = STANFORD_SW + '/solr/lib'
  Dir.glob("#{searchworks_lib_dir}/*.jar").each do |f|
    puts "copying #{f} to #{solr_lib}"
    FileUtils.cp f, solr_lib
  end
  
  # copy files from vanilla solr
  protwords = JETTY_HOME + '/../solr/conf/protwords.txt'
  FileUtils.cp protwords, solr_conf
end
