##########################################################################
# Copyright 2016 ThoughtWorks, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
##########################################################################

require 'json'
require 'timeout'
require 'fileutils'
require 'open-uri'
require 'logger'

RELEASES_JSON_URL = 'https://download.go.cd/experimental/releases.json'
STABLE_RELEASES_JSON_URL = 'https://download.go.cd/releases.json'
UPGRADE_VERSIONS_LIST = ENV['UPGRADE_VERSIONS_LIST'] || "16.8.0-3929, 16.10.0-4131, 16.12.0-4352"

task :test_installers do
  ['ubuntu-12.04', 'ubuntu-14.04', 'centos-6', 'centos-7'].each do |box|
    begin
      sh "GO_VERSION=#{full_version} vagrant up #{box} --provider #{ENV['PROVIDER'] || 'virtualbox'} --provision"
    rescue => e
      raise "Installer testing failed. Error message #{e.message}"
    ensure
      sh "vagrant destroy #{box} --force"
    end
  end
end

task :test_installers_w_postgres do
  ['ubuntu-14.04', 'centos-7'].each do |box|
    begin
      sh "GO_VERSION=#{full_version} USE_POSTGRES=yes vagrant up #{box} --provider #{ENV['PROVIDER'] || 'virtualbox'} --provision"
    rescue => e
      raise "Installer testing failed. Error message #{e.message}"
    ensure
      sh "vagrant destroy #{box} --force"
    end
  end
end


task :upgrade_tests do
  ['ubuntu-12.04', 'ubuntu-14.04', 'centos-6', 'centos-7'].each do |box|
      begin
        sh "GO_VERSION=#{full_version} TEST=upgrade_test UPGRADE_VERSIONS_LIST=\"#{UPGRADE_VERSIONS_LIST}\" vagrant up #{box} --provider #{ENV['PROVIDER'] || 'virtualbox'} --provision"
      rescue => e
        raise "Installer testing failed. Error message #{e.message}"
      ensure
        sh "vagrant destroy #{box} --force"
      end
  end
end

task :upgrade_tests_w_postgres do
  download_addons
  ['ubuntu-14.04', 'centos-7'].each do |box|
      UPGRADE_VERSIONS_LIST.split(/\s*,\s*/).each do |from_version|
        begin
          sh "GO_VERSION=#{full_version} TEST=upgrade_test UPGRADE_VERSIONS_LIST=#{from_version} USE_POSTGRES=yes vagrant up #{box} --provider #{ENV['PROVIDER'] || 'virtualbox'} --provision"
        rescue => e
          raise "Installer testing failed. Error message #{e.message}"
        ensure
          sh "vagrant destroy #{box} --force"
        end
      end
  end
end

def download_addons
  json = JSON.parse(open(STABLE_RELEASES_JSON_URL).read)
  myhash = json.sort {|a, b| a['go_full_version'] <=> b['go_full_version']}.reverse
  myhash.each_with_index do |key, index|
    if UPGRADE_VERSIONS_LIST.include? myhash[index]['go_full_version']
      if (!File.exists?("addons/go-postgresql-#{key['go_full_version']}.jar"))
        sh "curl -k -o addons/go-postgresql-#{key['go_full_version']}.jar #{ENV['ADDON_DOWNLOAD_URL']}/#{key['go_full_version']}/go-postgresql-#{key['go_full_version']}.jar"
      end
    end
  end
end

def full_version
  json = JSON.parse(open(RELEASES_JSON_URL).read)
  json.sort {|a, b| a['go_full_version'] <=> b['go_full_version']}.last['go_full_version']
end
