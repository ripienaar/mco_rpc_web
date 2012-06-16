class MCORPC
  class MCWrapper
    include MCollective::RPC

    attr_reader :agent

    def initialize(agent)
      @agent = rpcclient(agent)
      @agent.discovery_method = "mongo"
      @agent.progress = false
    end

    def disconnect
      @agent.disconnect
    end

    def ddl
      @agent.ddl
    end

    def discover
      @agent.discover
    end

    def apply_combined_filter(combinedfilter)
      combinedfilter.split(" ").each do |filter|
        begin
          @agent.fact_filter filter
        rescue
          @agent.class_filter filter
        end
      end
    end

    def stats
      @agent.stats
    end

    def call(action, arguments)
      request_arguments = {}
      arguments ||= {}

      ddl = @agent.ddl.action_interface(action)


      if arguments
        arguments.keys.each do |key|
          unless arguments[key] == ""
            skey = key.to_sym

            if ddl[:input][skey][:type] == :boolean
              request_arguments[skey] = MCollective::DDL.string_to_boolean(arguments[key]) unless arguments[key] == "unset"
            elsif [:integer, :float, :number].include?(ddl[:input][skey][:type])
              request_arguments[skey] = MCollective::DDL.string_to_number(arguments[key]) unless arguments[key] == "unset"
            else
              request_arguments[skey] = arguments[key]
            end
          end
        end
      end

      [@agent.send(action, request_arguments.clone), request_arguments]
    end

    def self.data_plugins
      MCollective::PluginManager.find(:data, "ddl").map do |data|
        ddl = MCollective::DDL.new(data, :data)
        [ data, ddl.meta[:description] ]
      end
    end

    def self.agents
      MCollective::PluginManager.find(:agent, "ddl").map do |agent|
        ddl = MCollective::DDL.new(agent)
        [ agent, ddl.meta[:description] ]
      end
    end
  end
end
