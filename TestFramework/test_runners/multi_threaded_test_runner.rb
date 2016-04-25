require File.expand_path(File.dirname(__FILE__) + '/../reporter/reporter')

require 'thread'
require 'timeout'
require 'securerandom'
require 'fileutils'

class MultiThreadedTestRunner
  
  def initialize(max_concurrent_processes, test_files, results_dir, format)
    
    # just quit if we don't get any files to run
    if (!test_files.instance_of?(Array) && !test_files.instance_of?(Hash)) or test_files.empty?
      puts "No tests to run."
      return
    end
    
    # check if the test_file is a map: {filename=>[method1, method2]} or an array of [filenames]
    # get the files that we need to load. (or have already loaded.)
    test_file_names = test_files.is_a?(Hash) ? test_files.keys : test_files
    
    # we'll keep a log of what each thread is doing, for troubleshooting/debugging
    @log = []
    $test_steps = Hash.new()
    # array to hold our threads
    @threads = []
    # a place to keep a list of tests that can run in parallel
    @parallel_test_queue = []
    @semaphore = Mutex.new
    
    @problem_scripts=[]
    
    # test manager may send same filename twice.
    test_file_names.uniq!
    
    # populate the file queue and domain list
    test_file_names.each do |f|
      require f
      test_class = Kernel.const_get(get_class_name(f))
      @parallel_test_queue << f
    end
    
    # start a thread for each process
    for x in 1..max_concurrent_processes.to_i do
      
      Thread.new do
        
        # set up an array keep track of each thread's activity (for logging)
        t = Thread.current
        t[:log] = []
        t[:log] << "Thread[#{x.to_s}]"
        
        begin
          
          # each thread will grab a test file to run, until there are no more left
          while !@parallel_test_queue.empty?
            test_to_run = grab_test
            
            # now execute the test class from within that file
            test_class = Kernel.const_get(get_class_name(test_to_run))
            
            t[:log] << Time.now.strftime("%H:%M:%S") + " - Running #{test_class}"
            
            # Runner
            Test::Unit::UI::Reporter.new(test_class, results_dir, test_to_run, format).run
          
          end # while loop
          
          # when the thread is finished, push it's activities into the @log
          @semaphore.synchronize do
            @log.concat(t[:log] << "\n")
          end
          
        rescue Exception => e
          @problem_scripts << test_class << "\n"
          puts "ERROR: Unhandled exception thrown by an execution thread!"
          puts "\n#{e.inspect}\n" + e.backtrace.join("\n")
        end # begin/rescue
        
      end # Thread
    end # for loop
    
    # join all threads to main when there's no more parallel work to do
    begin
      Thread.list.each { |t| t.join if t != Thread.main }
    rescue Exception => e
      puts "ERROR: Unhandled exception thrown while joining execution threads!"
      puts "\n#{e.inspect}\n" + e.backtrace.join("\n")
    end
    @log << "Result Summary"
    puts @log.join("\n")
  end # initialize
  
  # this method looks for a test class name within a file and returns it (for execution)
  def get_class_name(file_name)
    file_name += ".rb" unless file_name =~ /\.rb$/
    f = File.open(file_name, "r")
    f.readlines.each { |line| return $1.strip if line =~ /class\ (.*)<\ ?Test/ }
    f.close
  end
  
  # this method returns a test from a given domain, and removes the test from the queue
  def grab_test
    @semaphore.synchronize do
      if test_file = @parallel_test_queue.pop
        return test_file
      end
    end
  end
  
end # class
