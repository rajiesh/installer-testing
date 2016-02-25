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

task :test_installers do
  version_json    = JSON.parse(File.read('version.json'))
  go_full_version = version_json['go_full_version']
#['ubuntu-12.04', 'ubuntu-14.04', 'centos-6', 'centos-7']
  ['ubuntu-12.04', 'ubuntu-14.04', 'centos-6', 'centos-7'].each do |box|

    begin
      sh "GO_VERSION=#{go_full_version} vagrant up #{box} --provider #{ENV['PROVIDER'] || 'virtualbox'} --provision"
    rescue => e
      raise "Installer testing failed. Error message #{e.message}"
    ensure
      sh "vagrant destroy #{box} --force"
    end
  end
end


task :upgrade_tests do
  version_json    = JSON.parse(File.read('version.json'))
  go_full_version = version_json['go_full_version']

  ['ubuntu-12.04', 'ubuntu-14.04', 'centos-6', 'centos-7'].each do |box|
      begin
        sh "GO_VERSION=#{go_full_version} TEST=upgrade_test vagrant up #{box} --provider #{ENV['PROVIDER'] || 'virtualbox'} --provision"
      rescue => e
        raise "Installer testing failed. Error message #{e.message}"
      ensure
        sh "vagrant destroy #{box} --force"
      end
  end
end
