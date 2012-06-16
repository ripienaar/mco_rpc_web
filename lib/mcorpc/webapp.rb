class MCORPC
  class WebApp < Sinatra::Base
    def initialize
      MCollective::Applications.load_config

      @rpcutil = MCWrapper.new("rpcutil")

      super
    end

    set :static, true
    set :views, File.join(File.expand_path(File.dirname(__FILE__)), "../..", "views")

    if Sinatra.const_defined?("VERSION") && Gem::Version.new(Sinatra::VERSION) >= Gem::Version.new("1.3.0")
      set :public_folder, File.join(File.expand_path(File.dirname(__FILE__)), "../..", "public")
    else
      set :public, File.join(File.expand_path(File.dirname(__FILE__)), "../..", "public")
    end

    helpers do
      include Rack::Utils

      def render_input_form(input, input_interface)
        @input_name = input
        @input_interface = input_interface
        erb :"agent/render_input_form"
      end

      alias_method :h, :escape_html

      def display_result(result)
        if result.is_a?(String)
          if result.include?("\n")
            "<pre>%s</pre>" % result.split("\n").map{|r| h(r)}.join("<br>")
          else
            h(result)
          end
        elsif result.is_a?(Hash)
          out = StringIO.new
          out.puts "<table class='hash_result_set'>"

          result.keys.sort_by{|k| k.to_s}.each do |r|
            out.puts "<tr><td class='hr_key'>%s</td><td class='hr_value'>%s</td></tr>" % [h(r), display_result(result[r])]
          end
          out.puts "</table>"
          out.string
        elsif result.is_a?(Array)
          out = StringIO.new
          result.each do |r|
            out.puts "%s<br>" % display_result(r)
          end
          out.string
        elsif result.nil?
          ""
        elsif [Float, Fixnum, Date, Time].include?(result.class)
          result.to_s
        elsif result.is_a?(TrueClass)
          '<i class="icon-ok"></i>'
        elsif result.is_a?(FalseClass)
          '<i class="icon-remove"></i>'
        else
          "<pre>" + h(result.pretty_inspect) + "</pre>"
        end
      end

      def label_for_code(code, msg="")
        case code
          when 0
            '<span rel="tooltip" title="%s" class="label label-success">ok</span>' % msg
          when 1
            '<span rel="tooltip" title="%s" class="label label-important">aborted</span>' % msg
          when 2
            '<span rel="tooltip" title="%s" class="label label-warning">unknown action</span>' % msg
          when 3
            '<span rel="tooltip" title="%s" class="label label-important">missing data</span>' % msg
          when 4
            '<span rel="tooltip" title="%s" class="label label-important">invalid data</span>' % msg
          when 5
            '<span rel="tooltip" title="%s" class="label label-important">unknown error</span>' % msg
        end
      end
    end

    get '/' do
      erb :index
    end

    get '/data/:data_plugin' do
      @agent = "rpcutil"
      @data_plugin = params[:data_plugin]
      @ddl = MCollective::DDL.new(@data_plugin, :data)
      erb :"data/data_overview"
    end

    get '/data/:data_plugin/query' do
      @agent = "rpcutil"
      @data_plugin = params[:data_plugin]
      @ddl = MCollective::DDL.new(@data_plugin, :data)

      @client = MCWrapper.new(@agent)
      @client.agent.timeout = @client.agent.discovery_timeout + @ddl.meta[:timeout]

      begin
        if params["filter"]["identity"]
          @client.agent.discover :nodes => params["filter"]["identity"]
        elsif params["filter"]["combined"]
          @client.apply_combined_filter(params["filter"]["combined"])
        end

        @results, @arguments = @client.call("get_data", params["arguments"].merge({:source => @data_plugin}))
      rescue Exception => e
        @results = []
        @error = "Failed to run request <em>%s#%s</em>: <strong>%s</strong> (%s)" % [@agent, @action, e.to_s, e.class]
      end

      @arguments ||= {}

      erb :"data/result_view"
    end

    get '/agent/:agent' do
      @agent = params[:agent]
      @ddl = MCollective::DDL.new(@agent)
      @actions = @ddl.actions
      erb :"agent/agent_overview"
    end

    get '/agent/:agent/discover/combined/:filter' do
      @agent = params[:agent]
      @client = MCWrapper.new(@agent)

      @client.apply_combined_filter(params["filter"])

      content_type :json

      if params["groupsize"]
        @client.discover.sort.in_groups_of(Integer(params["groupsize"])).to_json
      else
        @client.discover.sort.to_json
      end
    end

    get '/agent/:agent/run/:action' do
      @agent = params[:agent]
      @action = params[:action]

      @client = MCWrapper.new(@agent)
      @ddl = @client.ddl
      @actions = @ddl.actions
      @verbose = params["options"]["verbose"] rescue false

      begin
        if params["filter"]["identity"]
          @client.agent.discover :nodes => params["filter"]["identity"]
        elsif params["filter"]["combined"]
          @client.apply_combined_filter(params["filter"]["combined"])
        end

        @results, @arguments = @client.call(@action, params["arguments"])
      rescue Exception => e
        @results = []
        @error = "Failed to run request <em>%s#%s</em>: <strong>%s</strong> (%s)" % [@agent, @action, e.to_s, e.class]
      end

      @arguments ||= {}

      erb :"agent/generic_result_view"
    end

    get '/agent/:agent/action/:action' do
      @agent = params[:agent]
      @action = params[:action]

      @ddl = MCollective::DDL.new(@agent)
      @actions = @ddl.actions
      @action_interface = @ddl.action_interface(@action)
      @client = MCWrapper.new(@agent)

      @optional_inputs = @action_interface[:input].keys.map do |input|
        input if @action_interface[:input][input][:optional]
      end.compact

      @required_inputs = @action_interface[:input].keys.map do |input|
        input unless @action_interface[:input][input][:optional]
      end.compact

      erb :"agent/render_agent_form"
    end
  end
end
