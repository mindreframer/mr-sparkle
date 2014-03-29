require_relative "mr-sparkle/version"
require 'listen'

module Mr
  module Sparkle
    extensions = %w(
      builder coffee creole css slim erb erubis
      haml html js less liquid mab markdown md mdown mediawiki mkd mw
      nokogiri radius rb rdoc rhtml ru
      sass scss str textile txt wiki yajl yml
    ).sort
    DEFAULT_RELOAD_PATTERN      = %r(\.(?:builder #{extensions.join('|')})$)
    DEFAULT_FULL_RELOAD_PATTERN = /^Gemfile(?:\.lock)?$/

    class Daemon
      attr_accessor :options, :unicorn_args
      attr_accessor :unicorn_pid

      def initialize(options, unicorn_args)
        @options, @unicorn_args = options, unicorn_args
        options[:pattern]       ||= DEFAULT_RELOAD_PATTERN
        options[:full]          ||= DEFAULT_FULL_RELOAD_PATTERN
        options[:force_polling] ||= false
        self
      end

      def start_unicorn
        @unicorn_pid = Kernel.spawn('unicorn', '-c', unicorn_config, *unicorn_args)
      end

      def unicorn_config
        File.expand_path('mr-sparkle/unicorn.conf.rb',File.dirname(__FILE__))
      end

      # TODO maybe consider doing like: http://unicorn.bogomips.org/SIGNALS.html
      def reload_everything
        Process.kill(:QUIT, unicorn_pid)
        Process.wait(unicorn_pid)
        start_unicorn
      end

      # Send a HUP to unicorn to tell it to gracefully shut down its
      # workers
      def hup_unicorn
        Process.kill(:HUP, unicorn_pid)
      end

      def handle_change(modified, added, removed)
        $stderr.puts "File change event detected: #{{modified: modified, added: added, removed: removed}.inspect}"
        if (modified + added + removed).index {|f| f =~ full_reload_pattern}
          reload_everything
        else
          hup_unicorn
        end
      end

      def listener
        @listener ||= begin
          x = Listen.to(Dir.pwd, :relative_paths=>true, :force_polling=> options[:force_polling]) do |modified, added, removed|
            handle_change(modified, added, removed)
          end

          x.only([ options[:pattern], options[:full] ])
          x
        end
      end

      def run
        shutdown = lambda do |signal|
          listener.stop
          Process.kill(:TERM, @unicorn_pid)
          Process.wait(@unicorn_pid)
          exit
        end
        Signal.trap(:INT, &shutdown)
        Signal.trap(:EXIT, &shutdown)
        listener.start
        start_unicorn

        # And now we just want to keep the thread alive--we're just waiting around to get interrupted at this point.
        sleep(99999) while true
      end

    end
  end
end
