# Rcqm main module : Contains one class for each metric returned by rcqm
module Rcqm

  # Metric class : Main class containing methods shared
  # by all subclasses for each metric
  class Metric

    # Metric constructor with command line interpretation
    # @param options [Hash] Options values parsed form the command line
    def initialize(options)
      @options = options      
      check_options_values
    end

    # Handle options specified on command line
    # Define directories/files to analyze
    # Define directories/files to remove from the analyze
    # Ignore unknown files
    def check_options_values
      # Check if files specified with -f option exist
      if @options[:files].nil?
        @files = ['lib', 'bin', 'app', 'test', 'spec', 'feature']
      else
        @files = @options[:files].split(',')
        @files.delete_if do |filename|
          unless File.exist?(filename)
            puts "#{filename} does not exist. Ignore it."
            true
          end
        end
        if @files.empty?
          puts 'No file to analyze. Aborted!'
          exit
        end
      end
      # Check if files specified with -e option exist
      unless @options[:exclude].nil?
        @excluded_files = @options[:exclude].split(',')
        @excluded_files.delete_if do |filename|
          unless File.exist?(filename)
            puts "#{filename} does not exist. Ignore it."
            true
          end
        end
      end
    end

    # Recursive crossing of directory content
    # @param dirname [String] Name/Path of the directory to analyze
    # @return [Integer] Return code (0=SUCCESS, FAILED!=0)
    def check_dir(dirname)
      return_code = 0
      Dir.open(dirname).each do |subfile|
        # Exclude '.', '..', '.git' directories 
        next if (subfile.eql? '..') ||
                (subfile.eql? '.') ||
                (subfile =~ /.*\.git.*/) ||
                 in_excluded_files("#{dirname}/#{subfile}")
        if File.file?("#{dirname}/#{subfile}")
          # Backup files (generated by emacs for example) are not analyzed
          next if (subfile =~ /^\#/) ||
                  (subfile =~ /.*\~/) ||
                  (subfile !~ /\.rb$/)  # only ruby files are analyzed
          return_code |= check_file("#{dirname}/#{subfile}")
        elsif File.directory?("#{dirname}/#{subfile}")
          return_code |= check_dir("#{dirname}/#{subfile}")
        else
          $stderr.puts "#{subfile}: Unknown type of file. Ignore it!"
        end
      end
      return_code
    end

    # Return true if the file given in parameter must be exclude from the
    # analysis according to files specified on command line with
    # option '-e'
    # @param filename [String] Name/Path of file to check
    # @return [Boolean] True if excluded file
    def in_excluded_files(filename)
      unless @options[:exclude].nil? || @excluded_files.empty?
        @excluded_files.each do |excluded_file|
          return true if filename.eql? "#{excluded_file}"
        end
        false
      end
      false
    end

    # Start the metric evaluation for each file specified on command line
    # with option '-f' or the default ones if empty
    # @param metric_name [String] The metric name to evaluate
    # @return [Integer] Return code (0=SUCCESS, FAILED!=0)
    def check(metric_name)
      return_code = 0
      @files.each do |filename|
        next if (filename.eql? '..') || (filename.eql? '.') ||
                in_excluded_files(filename) || !File.exist?(filename)
        if File.file?(filename) && filename =~ /\.rb$/ 
          return_code |= check_file(filename)
        elsif File.directory?(filename)
          return_code |= check_dir(filename)
        else
          $stderr.puts "#{filename}: Unknown type of file "\
                      "#{File.ftype(filename)} . Aborted!"
          exit
        end
      end
      puts
      puts ">>>>>>>>>>>>> #{metric_name} done <<<<<<<<<<<<<"
      return_code
    end

    # Remove color cosmetics for a given string
    # @param string [String] String to uncolorize
    def uncolorize(string)
      string.gsub(/\e\[(\d+)(;(\d+))*m/, '') 
    end

    # Report results return by the metric evaluation in the
    # corresponding json file
    # @param filename [String] Name/Path of the analyzed file
    # @param res [Array,Hash] Results to report
    # @param metric_name [String] Metric name evaluated
    def report_results(filename, res, metric_name)
      # Create dir 'reports' if it does not exist yet
      Dir.mkdir('reports', 0755) unless Dir.exist?('reports')
      
      # Get previous results if there are
      if File.exist?("reports/#{metric_name}.json")
        reports = JSON.parse(IO.read("reports/#{metric_name}.json"))
      else
        reports = {}
      end

      # Append new results
      append_results(reports, filename, res)

      # Update file
      File.open("reports/#{metric_name}.json", 'w') do |fd|
        fd.puts(JSON.pretty_generate(reports))
      end
    end
    
  end

end
