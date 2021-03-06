require "fileutils"
require "manageiq_performance/configuration"

# This is a wrapper middleware for the specific performance utility middlewares
# found in `lib/manageiq_performance/middlewares/`
module ManageIQPerformance
  class Middleware
    attr_reader :performance_middleware, :middleware_storage

    PERFORMANCE_HEADER = "HTTP_WITH_PERFORMANCE_MONITORING".freeze

    def initialize app
      @app = app
      @performance_middleware = []
      @middleware_storage     = []

      initialize_performance_middleware
      initialize_middleware_storage
    end

    def call env
      if env[PERFORMANCE_HEADER]
        performance_middleware_start env
      end
      @app.call env
    ensure
      if env[PERFORMANCE_HEADER]
        performance_middleware_finish env
      end
    end

    private

    def performance_header
      ::ManageIQPerformance::Middleware::PERFORMANCE_HEADER
    end

    def initialize_performance_middleware
      ManageIQPerformance.config.middleware.each do |name|
        begin
          require "manageiq_performance/middlewares/#{name}"

          module_name = name.split("_").map(&:capitalize).join
          middleware  = Object.const_get "ManageIQPerformance::Middlewares::#{module_name}"

          extend middleware
          @performance_middleware << name
        rescue NameError
        end
      end

      performance_middleware.each do |middleware|
        send "#{middleware}_initialize"
      end
    end

    def initialize_middleware_storage
      ManageIQPerformance.config.middleware_storage.each do |filename|
        begin
          require "manageiq_performance/middleware_storage/#{filename}"

          name    = filename.split("_").map(&:capitalize).join
          storage = Object.const_get "ManageIQPerformance::MiddlewareStorage::#{name}"

          @middleware_storage << storage.new
        rescue => e
          puts e.inspect
        end
      end
    end

    def performance_middleware_start env
      performance_middleware.each do |middleware|
        send "#{middleware}_start", env
      end
    end

    def performance_middleware_finish env
      performance_middleware.reverse.each do |middleware|
        send "#{middleware}_finish", env
      end
      middleware_storage.each { |storage| storage.finalize }
    end

    def save_report env, prefix, long_form, short_form
      middleware_storage.each do |storage|
        storage.record env, prefix, long_form, short_form
      end
    end
  end
end
