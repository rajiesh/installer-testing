##########################################################################
# Copyright 2018 ThoughtWorks, Inc.
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

require_relative 'helpers.rb'
require 'open-uri'
require 'timeout'
require 'json'
require 'net/http'
require 'rubygems'
require 'rubygems/version'
require 'fileutils'
include FileUtils

module Configuration
  class GoCDApiVersion
    V1 = 'application/vnd.go.cd.v1+json'.freeze
    V2 = 'application/vnd.go.cd.v2+json'.freeze
    V3 = 'application/vnd.go.cd.v3+json'.freeze
    V4 = 'application/vnd.go.cd.v4+json'.freeze
    V5 = 'application/vnd.go.cd.v5+json'.freeze
    V6 = 'application/vnd.go.cd.v6+json'.freeze

    def agents
      if current_gocd_version >= Gem::Version.new('16.10.0')
        V4
      else
        V3
      end
    end

    def pipelines
      if current_gocd_version >= Gem::Version.new('17.12.0')
        V5
      elsif current_gocd_version >= Gem::Version.new('17.4.0')
        V4
      elsif current_gocd_version >= Gem::Version.new('16.10.0')
        V3
      elsif current_gocd_version >= Gem::Version.new('16.7.0')
        V2
      else
        V1
      end
    end

    def pause
      if current_gocd_version >= Gem::Version.new('18.2.0')
        V1
      else
        'text/plain'
      end
    end

    def schedule
      if current_gocd_version >= Gem::Version.new('18.2.0')
        V1
      else
        'text/plain'
      end
    end

    def dashboard
      V1 if current_gocd_version >= Gem::Version.new('15.3.0')
    end

    def current_gocd_version
      Gem::Version.new(JSON.parse(open('http://localhost:8153/go/api/version', 'Accept' => V1).read)['version'])
    end
  end

  class ServerConfiguration

    def initialize(version)
      @version = version
      @auth = Authorization.new(version)
      # @configrepo = configrepo.new(version)
      # @elasticagents = elasticagents.new(version)
      # @analytics = analytics.new(version)
      @helper = Helper::SetUp.new
      @pipeline = Pipeline.new('testpipeline')
    end

    def setup
      @auth.setup if @auth.supported?
      # @configrepo.setup if @configrepo.supported?
      # @elastic_agents.setup if @elastic_agents.supported?
      # @analytics.setup if @analytics.supported?
      configure_server
    end

    def configure_server
      @pipeline.create
      @pipeline.unpause
      @pipeline.trigger
      assert_true @pipeline.passed?
    end

    def validate
      @pipeline.can_retrigger_pipeline?
      # @elastic_agents.validate
      # @analytics.validate
      # @configrepo.validate
    end
  end

  class Pipeline
    def initialize(name)
      @name = name
      @api_version = Configuration::GoCDApiVersion.new
    end

    def create
      url = 'http://localhost:8153/go/api/admin/pipelines'
      puts 'create a pipeline'
      sh(%(curl --silent --fail --location --dump-header - -X POST --user "admin:badger" -H "Accept: #{@api_version.pipelines}" -H "Content-Type: application/json" --data "@/vagrant/provision/filesystem/pipeline.json" #{url}))
    end

    def unpause
      url = "http://localhost:8153/go/api/pipelines/#{@name}/unpause"
      puts 'unpause the pipeline'
      sh(%(curl  -X POST --user "admin:badger" -H "Accept: #{@api_version.pause}" -H "Confirm: true" -H "X-GoCD-Confirm: true" #{url}))
    end

    def trigger
      url = "http://localhost:8153/go/api/pipelines/#{@name}/schedule"
      puts 'trigger the pipeline'
      sh(%(curl --silent --fail --location --dump-header - -X POST --user "admin:badger" -H "Accept: #{@api_version.schedule}" -H "Confirm: true" -H "X-GoCD-Confirm: true" #{url}))
    end

    def passed?
      Timeout.timeout(180) do
        loop do
          sleep 5
          dashboard_response = JSON.parse(open('http://localhost:8153/go/api/dashboard', http_basic_authentication: %w[admin badger], 'Accept' => @api_version.dashboard).read)

          if dashboard_response['_embedded']['pipeline_groups'][0]['_embedded']['pipelines'][0]['_embedded']['instances'][0]['_embedded']['stages'][0]['status'] == 'Passed'
            puts 'Pipeline completed with success'
            break
          end
        end
      end
    rescue Timeout::Error
      raise "Pipeline was not built successfully. The dashboard response was: #{dashboard_response}"
    end
  end

  class Authorization
    require 'fileutils'

    def initialize(version)
      @version = version
    end

    def supported?
      Gem::Version.new(@version) >= Gem::Version.new('17.5.0')
    end

    def setup
      p "Setting up file based authentication"
      sh(%(curl -X POST -H "Accept: application/vnd.go.cd.v1+json" -H "Content-Type: application/json" --data "@/vagrant/provision/filesystem/auth_plugin_settings.json" "http://localhost:8153/go/api/admin/security/auth_configs"))
    end

    def validate; end
  end

  class Analytics
    def initialize(version)
      @version = version
      @setup = Helper::SetUp.new
    end

    def supported?
      Gem::Version.new(@version) >= Gem::Version.new('18.2.0')
    end

    def setup
      sh "curl -L -o /var/lib/go-server/plugins/external/analytics-plugin.jar --fail -H 'Accept: binary/octet-stream' --user '#{ENV['EXTENSIONS_USER']}:#{ENV['EXTENSIONS_PASSWORD']}' #{ENV['ANALYTICS_PLUGIN_DOWNLOAD_URL']}"
      sh('/etc/init.d/go-server restart')
      @setup.service_status
    end

    def validate; end

    private

    def plugin_settings; end
  end

  class ElasticAgent
    def initialize(version)
      @version = version
      @setup = Helper::SetUp.new
    end

    def supported?
      Gem::Version.new(@version) >= Gem::Version.new('18.2.0')
    end

    def setup
      sh "curl -L -o /var/lib/go-server/plugins/external/ecs-elastic-agents-plugin.jar --fail -H 'Accept: binary/octet-stream' --user '#{ENV['EXTENSIONS_USER']}:#{ENV['EXTENSIONS_PASSWORD']}'  #{ENV['EA_PLUGIN_DOWNLOAD_URL']}"
      sh('/etc/init.d/go-server restart')
      @setup.service_status
    end

    def validate; end

    private

    def plugin_settings; end
  end
end
