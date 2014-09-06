class ENVied
  class EnvVarExtractor
    def self.defaults
      @defaults ||= begin
        {
          extensions: %w(ru thor rake rb yml ruby yaml erb builder markerb haml),
          globs: %w(*.* Thorfile Rakefile {app,config,db,lib,script,test,spec}/*)
        }
      end
    end

    def defaults
      self.class.defaults
    end

    def self.env_var_re
      @env_var_re ||= begin
        /^[^\#]*           # not matching comments
          ENV
          (?:              # non-capture...
            \[['"] |       # either ENV['
            \.fetch\(['"]  # or ENV.fetch('
          )
          ([a-zA-Z_]+)     # capture variable name
        /x
      end
    end

    attr_reader :globs, :extensions

    def initialize(options = {})
      @globs = options.fetch(:globs, self.defaults[:globs])
      @extensions = options.fetch(:extensions, self.defaults[:extensions])
    end

    def self.extract_from(globs, options = {})
      new(options.merge(globs: Array(globs))).extract
    end


    # Extract all keys recursively from files found via `globs`.
    # Any occurence of `ENV['A']` or `ENV.fetch('A')` in code (not in comments), will result
    # in 'A' being extracted.
    #
    # @param globs [Array<String>] the collection of globs
    #
    # @example
    #   EnvVarExtractor.new.extract(*%w(app lib))
    #   # => {'A' => [{:path => 'app/models/user.rb', :line => 2}, {:path => ..., :line => ...}],
    #         'B' => [{:path => 'config/application.rb', :line => 12}]}
    #
    # @return [<Hash{String => Array<String => Array>}>] the list of items.
    def extract(globs = self.globs)
      results = Hash.new { |hash, key| hash[key] = [] }

      Array(globs).each do |glob|
        Dir.glob(glob).each do |item|
          next if File.basename(item)[0] == ?.

          if File.directory?(item)
            results.merge!(extract("#{item}/*"))
          else
            next unless extensions.detect {|ext| File.extname(item)[ext] }
            File.readlines(item, :encoding=>"UTF-8").each_with_index do |line, ix|
              if variable = line[self.class.env_var_re, 1]
                results[variable] << { :path => item, :line => ix.succ }
              end
            end
          end
        end
      end

      results
    end
  end
end