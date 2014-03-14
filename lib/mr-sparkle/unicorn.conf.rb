worker_processes Integer(ENV["SPARKLE_WORKERS"] || 1)
timeout          Integer(ENV['SPARKLE_TIMEOUT'] || 5)
listen           Integer(ENV['SPARKLE_PORT']    || 3000)

GC.respond_to?(:copy_on_write_friendly=) and GC.copy_on_write_friendly = true

before_fork do |server, worker|
  require 'bundler'
  Bundler.require(:default, ENV["RACK_ENV"])
end
