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
    #DEFAULT_RELOAD_PATTERN = /\.(?:builder|coffee|creole|css|slim|erb|erubis|haml|html|js|less|liquid|mab|markdown|md|mdown|mediawiki|mkd|mw|nokogiri|radius|rb|rdoc|rhtml|ru|sass|scss|str|textile|txt|wiki|yajl|yml)$/

    DEFAULT_FULL_RELOAD_PATTERN = /^Gemfile(?:\.lock)?$/
    # TODO make configurable
    IGNORE_PATTERNS             = [/\.direnv/, /\.sass-cache/, /^tmp/]

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

      def log(msg)
        $stderr.puts msg
      end

      def start_unicorn
        @unicorn_pid = Kernel.spawn('unicorn', '-c', unicorn_config, *unicorn_args)
      end

      def unicorn_config
        File.expand_path('mr-sparkle/unicorn.conf.rb',File.dirname(__FILE__))
      end

      # TODO maybe consider doing like: http://unicorn.bogomips.org/SIGNALS.html
      def reload_everything
        log 'reloading everything'
        Process.kill(:QUIT, unicorn_pid)
        Process.wait(unicorn_pid)
        start_unicorn
      end

      def shutdown
        listener.stop
        Process.kill(:TERM, unicorn_pid)
        Process.wait(unicorn_pid)
        exit
      end

      # tell unicorn to gracefully shut down workers
      def hup_unicorn
        log 'hupping #{unicorn_pid}'
        Process.kill(:HUP, unicorn_pid)
      end

      def handle_change(modified, added, removed)
        log "File change event detected: #{{modified: modified, added: added, removed: removed}.inspect}"
        if (modified + added + removed).index {|f| f =~ options[:full]}
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
          IGNORE_PATTERNS.map{|ptrn| x.ignore(ptrn) }
          x
        end
      end

      def run
        that = self
        Signal.trap("INT") { |signo| that.shutdown }
        Signal.trap("EXIT") { |signo| that.shutdown }
        listener.start
        start_unicorn

        # And now we just want to keep the thread alive--we're just waiting around to get interrupted at this point.
        sleep(99999) while true
      end

    end
  end
end
