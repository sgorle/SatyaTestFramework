###################################################################
# = The GroupTestRunner looks at the grouping property of each test
# = file, to decide which ones to execute.  To qualify for execution,
# = a test must include each of the groupings specified in
# = the $groups_to_run variable.
# =
# = Author: SatyaRao Gorle
#
# @modified:
# If [OR] marker is specified, to qualify for execution, a test needs to
# simply include one of the groupings specified in $groups_to_run
#
# @modified: 
# Optimized for time taken to start up.
# Filter the files using grep and then require the files.
###################################################################

require 'find'
require 'yaml'
require 'shellwords'
require File.expand_path(File.dirname(__FILE__) + '/../valid_properties')
require File.expand_path(File.dirname(__FILE__) + '/../reporter/reporter')
require File.expand_path(File.dirname(__FILE__) + '/../shared/lib/framework_consts')
require File.expand_path(File.dirname(__FILE__) + '/../utils/framework_utils/framework_utils.rb')

class GroupTestRunner
  
  include ValidProperties
  
  TEST_FILE_PATTERNS = [/_test\.rb$/]
  
  # [0] pattern captures only 2 variables for a grep result: filename, groups
  # [1] pattern captures all different parts of the grep result
  GREP_PATTERNS = [/^(.*rb):.*=\s*\[(.*)\]/, /^(.*rb):(.*)=(.*)\[(.*)\](.*)/]
  
  attr_reader :expected_test_count
  
  # pass a comma-separated list of groups in a single string for execution
  def initialize(target_groups, target_priority, options = {})
    init_start_time = Time.now
    # this is the directory we'll recursively index for candidate tests
    @dir_to_index = File.expand_path(File.dirname(__FILE__) + '/../../tests/' + $test_module_path)
    @groups_not_to_run = ["deprecated"]
    @framework_utils = FrameworkUtils.new
    
    # check markers.
    @groups = target_groups.split(/[,\+]/).collect { |group| group.downcase.strip }
    
    # and initialize some other containers we'll be using to store various values during indexing
    init_containers(target_priority)
    
    # now find all of the test files in specified directory
    test_file_map = create_test_file_map()
    
    # build a hash of test files => groups (don't include the tests which are restricted from the current environment)
    test_file_to_group(test_file_map, false)
    
    # display associated tcid at the end of each test script file
    display_test_ids()
    
    # get expected test count
    @expected_test_count = @framework_utils.get_test_count(@files_to_run)
    
    init_end_time = Time.now
    puts "Time taken for analysis by test runner: #{(init_end_time - init_start_time)*1000}"
    
    if ! @duplicate_class_files.empty? and $find_duplicate_classes == "true"
      puts "These files has the duplicate class in the repository", @duplicate_class_files
      @duplicate_class_files.each do |f|
        if @files_to_run.include? f
          raise " ******** Terminating the execution since file:  #{f} has the duplicate class  ***************"
        end
      end
    end
    unless options[:dry_run] == 'true'
      MultiThreadedTestRunner.new($max_concurrent_tests, @files_to_run, $results_dir, :xml)
    end
    
  end
  
  def display_test_ids
    @files_to_run.sort.each do |f|
      print("\t#{f} (TCID: ", @file_tcids[f].inspect, ")\n")
      
      # save the tcids from each test script file
      @file_tcids[f].flatten.each { |t| @tcids_in_files_to_run << t }
    end
    
    # display the number of unique tcids
    puts("\nFound #{@tcids_in_files_to_run.uniq.length} test cases based on TCID attributes:")
    
    # display tcids in 10 columns/row
    idx = 0
    @tcids_in_files_to_run.sort.uniq.each do |id|
      if (idx % 10 == 0) # 10 columns/row
        if (idx > 0)
          print "\n"
        end
        print "\t"
      end
      idx += 1
      print ("%-8s " % id) # assuming tcid length is < 8 chars
    end
  end
  
  # This method takes 2 inputs . one is the hash map of test_file => class name
  # and the other is output of check_marker() i.e using_or is 'true / false'
  # And then builds the file groups that need to run.
  def test_file_to_group(test_file_map, using_or)
    puts "\nAnalyzing #{@test_files.length} test files... Stand by."
    @test_files.each do |tf|
      @skip = false
      ################
      test_class = Kernel.const_get(test_file_map[tf])
      
      # Lower cases the group only if each element in the grouping array is a string.
      # Note: The check is there to work around cases like below.
      # @properties[:grouping] = [CAD, CONNECT_AWLI, CONNECT], JOBS, JOBS_GRP5
      test_class.properties[:grouping].map!{|g| g.downcase if g.kind_of?(String)}
      
      ## Check if the test has any group that we need not run.
      @skip = false
      test_class.properties[:grouping].each do |g|
        if @groups_not_to_run.include?(g)
          @skip = true
        end
      end
      
      ## check if tcid is present in the file. if not then skip the file
      next if (test_class.properties[:tcid].nil? || test_class.properties[:tcid].length < 1)
      
      # If tcid is present, then ensure that they are numbers only!
      @skip_tcid = false
      test_class.properties[:tcid].each do |tc|
        @skip_tcid = true if !is_a_number?(tc)
      end
      
      # Check for priority
      if test_class.properties[:priority].nil?
        # If not defined or if not as per argument 'priority' then skip this test class
        puts "PRIORITY property not defined. Skipping file: #{tf}" if $debug_mode == "true"
        next
      end
      
      # If @priority_to_run is equal to MASTER PRIORITY then do not check if priority to run exists in the test class.
      # If @priority_to_run is not equal to MASTER PRIORITY then check if priority to run matches @priority_to_run in
      # the test class; skip test if it does not match.
      # puts "@priority_to_run = #{@priority_to_run}"
      @check_priority = (@priority_to_run.eql?("") or @priority_to_run.eql?(MASTER_PRIORITY.downcase))
      if @check_priority == false
        @target_priority_present = test_class.properties[:priority].include?(@priority_to_run)
        if @target_priority_present == false
          next
        end
      end
      ##########################
      # Get the grouping and service property from the file and add it to the @file_group hash
      # Basically file_groups is a hash with file name as key and an array of all groups
      # present in the file as the value
      @file_groups[tf] = [] if test_class.properties[:grouping].length > 0      
      test_class.properties[:grouping].each { |group| @file_groups[tf] << group }      
      ##########################
      # Get the tcid property from the file and add it to the @file_tcids hash
      # Basically @file_tcids is a hash with file name as key and an array of all tcid
      # present in the file as the value
      tcids = test_class.properties[:tcid]
      @file_tcids[tf] = tcids unless tcids.empty?
    end
    
    # "and" operator is default
    # for each file, compare the intersection of groups vs groups to run.
    # if the intersection exactly matches groups to run, lets see about running it.
    @file_groups.each_pair { |f, g| @files_to_run << f if (@groups_to_run & g) == @groups_to_run and !(@groups_not_to_run & g).any? }
    
    if @priority_to_run.eql?("")
      puts "\nFound #{@files_to_run.length} tests grouped for execution. Priority was not defined, so taking as ALL."
    else
      puts "\nFound #{@files_to_run.length} tests grouped for execution which have the desired priority = #{@priority_to_run} to run:"
    end
  end
  
  
  # This method checks if the definition of @properties has been commented.
  # Conservative approach: If it cannot parse, it returns it as a valid comment
  def valid_comment(grep_result_item)
    # capture all parts of grep result
    parts = GREP_PATTERNS[1].match(grep_result_item)
    
    # unable to parse the line. Potentially array appended in different format.
    # Example: #@properties[:grouping].append(3)
    return true if parts.nil?
    
    # line commented.
    # Example: '#@properties[:grouping] =' or '@properties = #'
    return false if parts.captures[1].include?("#") || parts.captures[2].include?("#")
    
    # return true in case of a valid comment at the end.
    # Example @properties[:grouping] = [HAL] # descriptive comment
    return true
  end
  
  # This method finds all the files with the mentioned groups
  # and services
  def grep_files_by_properties
    # I - filter on @properties[:grouping] keywords.
    property_filter = "@properties[:grouping]"
    
    #    @services_to_run ||= []
    @groups_to_run ||= []
    
    # groups to run may contain something like ["g1,g2,g3","g4,g5,g6"]
    groups_to_run_filter = @groups_to_run.map {|g| g.split(',')}.flatten.uniq
    
    # adding services and groups to filter
    group_filter = groups_to_run_filter.join('|')
    
    # grep -rw '@properties[:grouping]|@properties[:services] ../tests'
    grep_cmd1 =  "grep -rw '#{property_filter.shellescape}' #{@dir_to_index} "
    
    # grep -rw 'service1|service2|group1|group2'
    grep_cmd2 =  "grep -iw \"#{group_filter.shellescape}\""
    
    # Command to apply both the grep filters
    # = grep_cmd1 | grep_cmd2
    grep_cmd = "#{grep_cmd1}|#{grep_cmd2}"
    
    cmd_result = %x[ #{grep_cmd} ]
    
    grep_result_list = cmd_result.nil? ? [] : cmd_result.split("\n")
    
  end
  
  # Sample grep result item: /path/to/file/file_test.rb: @properties[:grouping] = [HAL]
  def parse_grep_result grep_result_list
    candidate_files = []
    grep_result_list.each do |gr|
      result_captures = GREP_PATTERNS[0].match(gr)
      
      # conservative approach. if grep result is not parsable, add that file
      if result_captures.nil?
        candidate_files << gr.split(":",2)[0]
        next
        # if the comment is not valid. skip that file.
      elsif !valid_comment(gr)
        next
      end
      
      file_name, group_list = result_captures.captures
      groups = group_list.split(",").map{|i| i.strip}
      
      # add file if the group instersection is non-empty
      candidate_files << file_name if (@groups_to_run & groups)
    end
    candidate_files
  end
  
  def create_test_file_map
    grep_result_list = grep_files_by_properties
    candidate_files = parse_grep_result grep_result_list
    
    candidate_files.each do |f|
      TEST_FILE_PATTERNS.each do |re|
       (@files << f; break) if f =~ re && !f.downcase.reverse.split("/", 2)[1].reverse.include?('deprecate')
      end
    end
    
    # Maps file to its class name. This is to avoid calling get_class_name multiple times. file => class_name
    test_file_map = {}
    @files.each do |f|
      class_name = @framework_utils.get_test_class_name(f)
      begin
        # skip if the file doesn't have a class name.
        next if class_name.nil?
        # Includes the test file.
        require f
      rescue Exception => e
        if $debug_mode == "true"
          puts "Rescuing exceptions raised, continuing with execution: TEST SCRIPT #{f} IS BEING SKIPPED "
          puts "Exception caught: #{e.message}"
        end
        next
      end
      if (!test_file_map[f])
        if test_file_map.has_value? (class_name) and $find_duplicate_classes == "true"
          @duplicate_class_files << f
          test_file_map[f]= class_name
        else
          test_file_map[f] = class_name
        end
        @test_files << f
      end
    end
    
    return test_file_map
  end
  
  def init_containers(target_priority)
    @files = []
    @test_files = []
    @file_groups = {}
    @files_to_run = []
    @duplicate_class_files = []
    @groups_to_run = []
    @file_tcids = {} # hash to hold file-tcid pairs
    @tcids_in_files_to_run = [] # tcids from the test files in @files_to_run
    
    # priority which is to be run for this test run
    @priority_to_run = target_priority.downcase.strip
    
    # Set the @priority_to_run to empty string. If the argument target_priority is not empty then assign it to @priority_to_run
    # if the priority_to_run is empty , then takes it as ALL
    # else takes the given priority into priority_to_run
    if @priority_to_run.eql?('')
      puts "\nPriority required for this test run is not defined. So taking it as ALL\n"
    else
      puts "\nPriority required for this test run is: #{@priority_to_run}\n"
    end
    
    puts "\nINITIALIZING CUSTOM RUN FOR:"
    
    # Check if groups is passed as the parameter
    if @groups.length >= 1
      @groups_to_run = @groups 
    end
    puts "Groups to run: #{@groups_to_run.inspect}"
    @groups_to_run.each { |group| puts "\t#{group}" }
  end
  
  # Method to test if a given string is a number
  def is_a_number?(s)
    s.to_s.match(/\A[+-]?\d+?(\.\d+)?\Z/) == nil ? false : true
  end
  
end
