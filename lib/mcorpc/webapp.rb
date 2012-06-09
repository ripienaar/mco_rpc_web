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
        erb :render_input_form
      end

      alias_method :h, :escape_html

      def display_result(result)
        if result.is_a?(String)
          if result.include?("\n")
            "<pre>%s</pre>" % result.split("\n").map{|r| h(r)}.join("<br>")
          else
            result
          end
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
          "<pre>" + result.pretty_inspect + "</pre>"
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


      erb :generic_result_view
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

      erb :render_agent_form
    end

    get '/agent/:agent' do
      @agent = params[:agent]
      @ddl = MCollective::DDL.new(@agent)
      @actions = @ddl.actions
      erb :agent_overview
    end
  end
end