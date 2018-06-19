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

require 'json'

Module Helper do
  class SetUp
    def server_version
      versions = JSON.parse(open('http://localhost:8153/go/api/version', 'Accept' => V1).read)
      "#{versions['version']}-#{versions['build_number']}"
    end

    def current_gocd_version
      Gem::Version.new(JSON.parse(open('http://localhost:8153/go/api/version', 'Accept' => V1).read)['version'])
    end

    def addon_for(core)
      versions_map = JSON.parse(File.read('/vagrant/addons/addon_builds.json'))
      versions_map.select { |v| v['gocd_version'] == core }.last['addons']['postgresql']
    end

    def server_running?
      ping_response = ping_server
      ping_response.is_a?(Net::HTTPFound) || ping_response.is_a?(Net::HTTPSuccess)
    rescue StandardError => e
      false
    end

    def ping_server
      Net::HTTP.get_response(URI('http://localhost:8153/go/auth/login'))
    end

    def wait_to_start
      puts 'Wait server to come up'
      Timeout.timeout(120) do
        loop do
          begin
            puts '.'
            break if server_running?
          rescue Errno::ECONNREFUSED
          end
          sleep 5
        end
      end
    end

    def service_status
      wait_to_start

      # check if server startup with postgres only
      if ENV['USE_POSTGRES']
        Timeout.timeout(120) do
          loop do
            if File.open('/var/log/go-server/go-server.log').lines.any? { |line| line.include?('Using connection configuration jdbc:postgresql://localhost:5432/cruise [User: postgres] [Password Encrypted: false]') }
              p 'server up with postgres'
              break
            end
          end
        end
      end

      puts 'wait for agent to come up'
      Timeout.timeout(180) do
        loop do
          agents = JSON.parse(open('http://localhost:8153/go/api/agents', 'Accept' => agent_api_version).read)['_embedded']['agents']

          if agents.any? { |a| a['agent_state'] == 'Idle' }
            puts 'Agent is up'
            break
          end
        end
      end
    end

    def setup_postgres_addon(version)
      p 'Setting up postgres addon'
      sh('/etc/init.d/go-server stop 2>/dev/null || true')
      addon = addon_for version
      sh('echo GO_SERVER_SYSTEM_PROPERTIES=\"\$GO_SERVER_SYSTEM_PROPERTIES -Dgo.database.provider=com.thoughtworks.go.postgresql.PostgresqlDatabase\" >> /etc/default/go-server')

      sh(%(su - go bash -c 'mkdir -p /var/lib/go-server/addons ; rm -rf /var/lib/go-server/addons/*.jar ; cp /vagrant/addons/#{addon} /var/lib/go-server/addons/'))
      sh(%(su - go bash -c 'echo "db.host=localhost"  >> /etc/go/postgresqldb.properties'))
      sh(%(su - go bash -c 'echo "db.port=5432"  >> /etc/go/postgresqldb.properties'))
      sh(%(su - go bash -c 'echo "db.name=cruise"  >> /etc/go/postgresqldb.properties'))
      sh(%(su - go bash -c 'echo "db.user=postgres"  >> /etc/go/postgresqldb.properties'))
      sh(%(su - go bash -c 'echo "db.password=postgres"  >> /etc/go/postgresqldb.properties'))
    end

    def change_postgres_addons_jar
      if ENV['USE_POSTGRES']
        addon = addon_for ENV['GO_VERSION']
        sh(%(su - go bash -c 'rm -rf /var/lib/go-server/addons/*.jar ; cp /vagrant/addons/#{addon} /var/lib/go-server/addons/'))
        sh('/etc/init.d/go-server restart')
      end
    end

    def start_agent
      sh('/etc/init.d/go-agent start')
    end
  end
end
