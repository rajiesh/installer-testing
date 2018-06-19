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

require 'lib/helpers.rb'

class GoCDApiVersion
  V1 = 'application/vnd.go.cd.v1+json'.freeze
  V2 = 'application/vnd.go.cd.v2+json'.freeze
  V3 = 'application/vnd.go.cd.v3+json'.freeze
  V4 = 'application/vnd.go.cd.v4+json'.freeze
  V5 = 'application/vnd.go.cd.v5+json'.freeze
  V6 = 'application/vnd.go.cd.v6+json'.freeze

  def agent_api_version
    if current_gocd_version >= Gem::Version.new('16.10.0')
      V4
    else
      V3
    end
  end

  def pipeline_api_version
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

  def pause_api_version
    if current_gocd_version >= Gem::Version.new('18.2.0')
      V1
    else
      'text/plain'
    end
  end

  def schedule_api_version
    if current_gocd_version >= Gem::Version.new('18.2.0')
      V1
    else
      'text/plain'
    end
  end

  def dashboard_api_version
    V1 if current_gocd_version >= Gem::Version.new('15.3.0')
  end
end

class ServerConfiguration
  def initialize(version)
    @version = version
    @auth = authorization.new(vesion)
    @configrepo = configrepo.new(version)
    @elasticagents = elasticagents.new(version)
    @analytics = analytics.new(version)
    @setup = Helper::SetUp.new
  end

  def setup
    @auth.setup if @auth.supported?
    @configrepo.setup if @configrepo.supported?
    @elastic_agents.setup if @elastic_agents.supported?
    @analytics.setup if @analytics.supported?
    @setup.configure_server
  end

  def validate
    @setup.can_retrigger_pipeline?
    @elastic_agents.validate
    @analytics.validate
    @configrepo.validate
  end
end

class Pipeline
  def initialize(name)
    self.name = name
  end

  def create
    url = 'http://localhost:8153/go/api/admin/pipelines'
    puts 'create a pipeline'
    sh(%(curl --silent --fail --location --dump-header - -X POST -H "Accept: #{GoCDApiVersion.api_version}" -H "Content-Type: application/json" --data "@/vagrant/provision/filesystem/pipeline.json" #{url}))
  end

  def unpause
    url = "http://localhost:8153/go/api/pipelines/#{@name}/unpause"
    puts 'unpause the pipeline'
    sh(%(curl --silent --fail --location --dump-header - -X POST -H "Accept: #{pause_api_version}" -H "Confirm: true" -H "X-GoCD-Confirm: true" #{url}))
  end

  def trigger
    url = "http://localhost:8153/go/api/pipelines/#{@name}/schedule"
    puts 'trigger the pipeline'
    sh(%(curl --silent --fail --location --dump-header - -X POST -H "Accept: #{schedule_api_version}" -H "Confirm: true" -H "X-GoCD-Confirm: true" #{url}))
  end

  def passed?
    Timeout.timeout(180) do
      loop do
        sleep 5
        dashboard_response = JSON.parse(open('http://localhost:8153/go/api/dashboard', 'Accept' => dashboard_api_version).read)

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
  attr_reader version

  def initialize(version)
    self.version = version
  end

  def supported?
    version >= Gem::GoVersion.new('17.5.0')
  end

  def setup
    RestClient.post
  end

  def validate
    RestClient.get
    assert
  end
end


class Analytics
  attr_reader version

  def initialize(version)
    self.version = version
    @setup = Helper::SetUp.new
  end

  def supported?
    version >= Gem::GoVersion.new('18.2.0')
  end

  def setup
    sh "curl -L -o /var/lib/go-server/plugins/external/analytics-plugin.jar --fail -H 'Accept: binary/octet-stream' --user '#{ENV['EXTENSIONS_USER']}:#{ENV['EXTENSIONS_PASSWORD']}' #{ENV['ANALYTICS_PLUGIN_DOWNLOAD_URL']}"
    sh('/etc/init.d/go-server restart')
    @setup.service_status
  end

  def validate
    RestClient.get
    assert
  end

  private

  def plugin_settings
  end
end

class ElasticAgent

  def initialize(version)
    self.version = version
    @setup = Helper::SetUp.new
  end

  def supported?
    version >= Gem::GoVersion.new('18.2.0')
  end

  def setup
    sh "curl -L -o /var/lib/go-server/plugins/external/ecs-elastic-agents-plugin.jar --fail -H 'Accept: binary/octet-stream' --user '#{ENV['EXTENSIONS_USER']}:#{ENV['EXTENSIONS_PASSWORD']}'  #{ENV['EA_PLUGIN_DOWNLOAD_URL']}"
    sh('/etc/init.d/go-server restart')
    @setup.service_status
  end

  def validate
    RestClient.get
    assert
  end

  private

  def plugin_settings
  end
end
