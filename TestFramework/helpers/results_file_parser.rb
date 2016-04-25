require 'rexml/document'
require 'rexml/xpath'
require 'open-uri'
require 'find'

#include REXML

module ResultsFileParser

  # returns a list of failed test classes, given a file or directory path
  def get_failed_test_classes(fn)
    failed_tests = []
    failed_classes = []

    results = get_test_results(fn)

    failed_tests << results[:fail]
    failed_tests << results[:error]

    failed_tests.flatten.each do |test|
      if data = /(.*):/.match(test)
        failed_classes << data[1]
      else
        puts "WARN: couldn't parse class name from test -- #{test}"; next
      end
    end

    return failed_classes
  end

  # returns hash of all test results, given a file or directory path
  def get_test_results(fn)
    results = { :pass => [], :fail => [], :error => [], :test_method_file => [] }

    if File.directory? fn
      files = Dir.entries(fn)
      files.each do |f|
        if f =~ /TEST-.*\.xml/
          these_results = get_test_results_from_file(File.join(fn, f))
          results[:pass].concat these_results[:pass]
          results[:fail].concat these_results[:fail]
          results[:error].concat these_results[:error]
          results[:test_method_file].concat these_results[:test_method_file]
        end
      end 
    else
      return get_test_results_from_file(fn)
    end
    return results
  end

  # returns a hash of all test results, given a single XML results file
  def get_test_results_from_file(fn)
    results = { :pass => [], :fail => [], :error => [], :test_method_file => [] }

    if fn =~ /^http/
      content = open(fn).read
    else
      content = File.read(fn)
    end

    doc = REXML::Document.new content
    root = doc.root

    REXML::XPath.each(root, "//testcase") do |tc|

      name = tc.attributes['name']
      classname = tc.attributes['classname']
      fullname = classname + ":" + name

      # mapping between file and method.
      test_method_file_map = { name => tc.attributes['file_path']}

      if child = tc.elements[1]
        case child.name
        when "error"
          results[:error] << fullname
          results[:test_method_file] << test_method_file_map
        when "failure"
          results[:fail] << fullname
          results[:test_method_file] << test_method_file_map
        else
          results[:pass] << fullname
        end
       end
    end
    results
  end

  # returns a text-based summary of results, given a file or directory path
  def summarize_results(fn)
    body = ""
    results = get_test_results(fn)
    total = results[:error].length + results[:fail].length + results[:pass].length
    total_failed = results[:fail].length + results[:error].length

    body << "Tests Executed: " + total.to_s + "\n"
    body << "Passed: " + results[:pass].length.to_s + "\n"
    body << "Failed: " + results[:fail].length.to_s + "\n"
    body << "Error: " + results[:error].length.to_s + "\n"
    body << ((results[:pass].length.to_f/total).round(4) * 100).to_s + "% Passed" + "\n"

    if results[:error].length != 0 || results[:fail].length != 0
      body << "\n"
      body << "Failed/Errored Tests:\n"
      (results[:error].concat(results[:fail])).each do |test|
        body << "   #{test}\n"
      end
    end
    
    puts "-" * 50
    puts body
    puts "-" * 50
    
    summary = {}
    summary[:body] = body
    
    bottom_line = "#{total_failed}/#{total} failed"
    summary[:bottom_line] = bottom_line
    
    return summary
  end
  
  def summarize_transient_results(fn_x, fn_y)
    body = ""
    results_x = get_test_results(fn_x)
    results_y = get_test_results(fn_y)
    fail_x = results_x[:fail] + results_x[:error]
    fail_y = results_y[:fail] + results_y[:error]
    total_x = results_x[:pass].length + results_x[:fail].length + results_x[:error].length
    
    results = { :consistent => [], :transient => [] }
    
    fail_x.each do |test|
      results[:consistent] << test if fail_y.include? test
      results[:transient] << test if results_y[:pass].include? test
    end
    
    body << "Persistent failures/errors (#{results[:consistent].length}):\n"
    results[:consistent].each { |test| body << "   #{test}\n" }
      
    body << "\nTransient failures/errors: (#{results[:transient].length}):\n"
    results[:transient].each { |test| body << "   #{test}\n" }
    
    summary = {}
    summary[:body] = body
    
    bottom_line = "#{fail_y.length}/#{total_x} failed (after rerun)"
    summary[:bottom_line] = bottom_line
    
    return summary
  end
    
  def sort_result_summary(summary)      
       new_hash = {}
       no_team = []
       body = ''
       owner_yaml = File.join($results_dir, "test_class_ownership.yaml")
  
       return summary if !File.exist?(owner_yaml) # there is no tests to re run or the owner test map was not available
                      
       owner_hash = YAML.load(File.open(owner_yaml))

       summary.each_line do |line|
         if line !~ /\w+:\w+/ # skipping lines that are not class:test
           body << line
           next
end
          t = /(\w+):.*/.match(line)
          test_name = t[0]
          class_name = t[1]        
          found = false

          owner_hash.each_pair do |key, value|        
            if value.include?(class_name)
              found = true
              new_hash[key] ||= []
              new_hash[key] << test_name
              break
            end
          end # owner_hash.each_pair        
          no_team << test_name if !found      
       end # summary.each_line

       # sort the new_hash by key into an array      
       (new_hash.sort).each do |key|  
           body << "\n"
           body << "\t#{key[0].upcase} - #{key[1].size} failures / #{owner_hash[key[0]].size}\n"
           body << "\n"      
           ((key.pop).sort).each {|i| body << "\t\t#{i}\n"}
       end

       if no_team.size != 0
         # print out the tests found no team to associate with
         body << "\n"
         body << "\tTests with no team to associate with -"
         no_team.each {|i| body << "\t\t#{i}\n"}
       end       
       return body
   end
    
end
