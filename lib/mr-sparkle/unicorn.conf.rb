worker_processes Integer(ENV["WEB_CONCURRENCY"] || 3)
timeout Integer(ENV['SPARKLE_TIMEOUT'] || 60)

GC.respond_to?(:copy_on_write_friendly=) and GC.copy_on_write_friendly = true

before_fork do |server, worker|
  require 'bundler'
  Bundler.require(:default, ENV["RACK_ENV"])
end
