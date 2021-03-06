require "manageiq_performance/configuration"
require "manageiq_performance/requestor"
require "manageiq_performance/reporting/requestfile_builder"

module ManageIQPerformance
  module Commands
    class Benchmark
      def self.help_text
        "make a request against the configured MIQ app"
      end

      def self.run(args)
        new(args).run
      end

      def initialize(args)
        @opts     = {:samples => 1}
        parse_env_variables
        option_parser.parse!(args)
        @path     = args.first
      end

      def run
        if @opts.has_key?(:requestfile)
          requestfile = @opts.delete(:requestfile)
          requests = Reporting::RequestfileBuilder.load requestfile
        elsif @path
          requests = [{:method => :get, :path => @path}]
        else # Invalid:  display help and exit
          puts option_parser.help
          exit
        end

        requestor = Requestor.new @opts
        requests.each do |request|
          @opts[:samples].to_i.times do
            requestor.public_send request[:method].downcase, request[:path]
          end
        end
      end

      private

      def parse_env_variables
        @opts[:host]        = ENV["MIQ_HOST"] || ENV["CFME_HOST"]
        @opts[:ignore_ssl]  = !!ENV["DISABLE_SSL_VERIFY"] || nil
        @opts[:requestfile] = ENV["REQUESTFILE"] || ENV["REQUEST_FILE"]
        @opts[:samples]     ||= ENV["COUNT"] || ENV["SAMPLES"]
        @opts.delete_if {|_,val| val.nil? }
      end

      def option_parser
        @optparse ||= OptionParser.new do |opt|
          opt.banner = "Usage: #{File.basename $0} benchmark [options] path"

          opt.separator ""
          opt.separator self.class.help_text.capitalize
          opt.separator ""
          opt.separator "Pass in either a `path` as the final argument for a single"
          opt.separator "request, or the --requestfile option to make multiple"
          opt.separator "requests against the application in serial.  The"
          opt.separator "--requestfile option can take a vaule, or left blank and"
          opt.separator "will used the value that is configured"
          opt.separator ""
          opt.separator "Default Requestfile location: tmp/manageiq_performance/Requestfile"
          opt.separator ""
          opt.separator "Options"

          opt.on("-HHOST", "--host=HOST",          "MIQ endpoint to target", define_host)
          opt.on("-mMETH", "--method=METHOD",      "HTTP method (def: GET)", http_method)
          opt.on("-d",     "--no-ssl",             "Disable SSL verify",     disable_ssl)
          opt.on("-r",     "--requestfile [FILE]", "Requestfile to use",     requestfile)
          opt.on("-cNUM",  "--count=NUM",          "Repeat request N times", set_count)
          opt.on("-sNUM",  "--samples=NUM",        "Alias for --count",      set_count)
          opt.on("-h",     "--help",               "Show this message") { puts opt; exit }
        end
      end

      def define_host
        Proc.new {|host| @opts[:host] = host }
      end

      def http_method
        Proc.new { @opts[:ignore_ssl] = true }
      end

      def disable_ssl
        Proc.new { @opts[:ignore_ssl] = true }
      end

      def set_count
        Proc.new {|num| @opts[:samples] = num }
      end

      def requestfile
        Proc.new do |requestfile|
          # Assign the requestfile option if:
          #
          #   - The current option is nil (nil will generate/use the default in
          #     the `Requestfile::Builder`
          #   - Re-assign it if a value is passed in (commandline options are
          #     favored over ENV vars, so if something is passed in, regardless
          #     if we have a value already, assign it to what is passed in.
          #
          if @opts[:requestfile].nil? || requestfile
            @opts[:requestfile] = requestfile
          end
        end
      end
    end
  end
end
