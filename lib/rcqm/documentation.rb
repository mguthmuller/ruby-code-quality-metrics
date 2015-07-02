require_relative 'metric.rb'
require 'json'
require 'colorize'

#  Rcqm module
module Rcqm

  # Documentation class, herited from metric class
  class Documentation < Rcqm::Metric

    # Constructor
    # @param args [Hash] Hash containing options values 
    def initialize(*args)
      super(*args)
      unless @options[:quiet]
        puts
        if @options[:jenkins]
          puts '***********************************************************'
          puts '******************* Documentation rates *******************'
          puts '***********************************************************'
        else
          puts '**********************************************************'.bold
          puts '******************* Documentation rates ******************'.bold
          puts '**********************************************************'.bold
        end
      end
    end

    # Launch `inch` one the file given in parameter and report results
    # @param filename [String] The path of the file to analyze
    # @return [Integer] Return code
    def check_file(filename)
      pwd = Dir.pwd
      Dir.chdir(File.dirname(filename))
      inch_res = `inch list --all #{File.basename(filename)}`
      Dir.chdir(pwd)
      results = parse_inch_output(uncolorize(inch_res))
      unless @options[:quiet] ||
             (results[:A].empty? &&
              results[:B].empty? &&
              results[:C].empty? &&
              results[:U].empty?)
        unless @options[:dev]
          puts
          @options[:jenkins] ?
            puts("=== #{filename} ===") :
            puts("=== #{filename} ===".bold)
        end
        print_documentation_rates(filename,results)
      end
      report_results(filename, results, 'documentation') if @options[:report]
      (results[:C].empty? && results[:U].empty?) ? 0 : 1
    end

    # Parse and format output returned by inch
    # @param output [String] Inch output
    # @return [Hash] Inch output formatted
    def parse_inch_output(output)
      grades = {
        :A => [],
        :B => [],
        :C => [],
        :U => []
      }
      output.lines do |line|
        next if line.strip.empty?
        break if  (line =~ /^Nothing to suggest/) ||
                  (line =~ /^You might want to look at these files/)
        splitted_line = line.split(' ')
        case splitted_line[1]
        when 'A'
          grades[:A] << splitted_line[3]
        when 'B'
          grades[:B] << splitted_line[3]
        when 'C'
          grades[:C] << splitted_line[3]
        when 'U'
          grades[:U] << splitted_line[3]
        end
      end
      grades
    end

    # Append new results in the json file
    # @param reports [Array] Previous results
    # @param filename [String] Name/Path of the analyzed file
    # @param res [Hash] Hash containing the new results to append
    def append_results(reports, filename, res)
      reports[filename] ||= []
      reports[filename] << {
        'Date' => Time.now,
        'Good documentation' => (res[:A].empty?) ? nil : res[:A],
        'Could be improved documentation' => (res[:B].empty?) ? nil : res[:B],
        'Need work documentation' => (res[:C].empty?) ? nil : res[:C],
        'Undocumented' => (res[:U].empty?) ? nil : res[:U]
      }
    end

    # Print formatted results of documentation rates
    # @param filename [String] Name of the analyzed file
    # @param res [Hash] Hash containing the results to print
    def print_documentation_rates(filename, res)
      unless (res[:A].empty?) || (@options[:dev])
        @options[:jenkins] ?
          puts('# Good documentation:') :
          puts('# Good documentation:'.green)
        res[:A].each do |item|
          puts "  - #{item}" 
        end
      end
      if (@options[:dev]) &&
         (!res[:B].empty? || !res[:C].empty? || !res[:U].empty?)
        puts
        @options[:jenkins] ?
          puts("=== #{filename} ===") :
          puts("=== #{filename} ===".bold)
      end
      unless res[:B].empty?
        @options[:jenkins] ?
          puts('# Properly documented, but could be improved:') :
          puts('# Properly documented, but could be improved:'.yellow)
        res[:B].each do |item|
          puts "  - #{item}" 
        end
      end
      unless res[:C].empty?
        @options[:jenkins] ?
          puts('# Need work:') :
          puts('# Need work:'.red)
        res[:C].each do |item|
          puts "  - #{item}" 
        end
      end
      unless res[:U].empty?
        @options[:jenkins] ?
          puts('# Undocumented:') :
          puts('# Undocumented:'.magenta)
        res[:U].each do |item|
          puts "  - #{item}" 
        end
      end
    end
    
  end
  
end
