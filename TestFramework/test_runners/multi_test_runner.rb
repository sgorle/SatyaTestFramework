require File.expand_path(File.dirname(__FILE__) + '/../../tests/test.properties.rb')
require File.expand_path(File.dirname(__FILE__) + '/group_test_runner')
require File.expand_path(File.dirname(__FILE__) + '/multi_threaded_test_runner')
require File.expand_path(File.dirname(__FILE__) + '/../utils/framework_utils/framework_utils.rb')

class MultiTestRunner < GroupTestRunner

   def initialize(tests_to_run, options={})
      @files = []
      @tests_to_run = []
      @framework_utils = FrameworkUtils.new

      # check that we have received hash.
      if $test_failed_methods == 'true' && !tests_to_run.include?("{")
        puts '*' * 81
        puts 'Flag test_failed_methods is set to true.'
        puts 'Wrong format for running failed test methods only. Please pass tests_run_name/tests_to_run as a hash.'
        puts "Falling back to normal running by scripts"
        puts '*' * 81
        $stdout.flush
        $test_failed_methods = 'false'
      elsif tests_to_run.include?("{")
        # test manager provides a UI flag where user may not explicitly set the ant-parameter for
        # running only test methods flag.
        puts "Setting flag test_failed_methods to true, since a hash is received in tests_run_name"
        $test_failed_methods = 'true'
      end
      
      if $test_failed_methods == 'true'
        # eval the hash received from test manager

        file_methods_map = parse_tests_to_run_from_tm tests_to_run
        puts "Methods to run: #{file_methods_map.to_json}"

        $stdout.flush
        files = file_methods_map.keys

        # we need to pass hash to multithread runner.
        @tests_to_run = {}
      else
        tests_name = tests_to_run
        p tests_name
        if tests_name.include?(AND_MARKER)
          tests_name.gsub!(AND_MARKER, ",")
        end
        files = tests_name.split(",")
      end


      if $http_tests == "true"
       base_path = File.dirname(__FILE__) + '/../../../http/' + $test_module_path
      else
        base_path = File.dirname(__FILE__) + '/../../../selenium/' + $test_module_path
      end
      puts base_path

      files.each do |file|
        file_with_path = File.expand_path(base_path) + file

        if $test_failed_methods == "true"
          @tests_to_run[file_with_path] = file_methods_map[file]
        else
          @tests_to_run << file_with_path
        end

      end

      @expected_test_count = if $test_failed_methods == "true"
                               puts "\n** Running only failed test methods **"
                               @tests_to_run.inject(0){|result,el| result += el[1].size}
                             else
                               @framework_utils.get_test_count(@tests_to_run)
                             end

      puts "\nFound #{@expected_test_count} tests to run."
      MultiThreadedTestRunner.new($max_concurrent_tests, @tests_to_run, $results_dir, :xml)
   end

   # Response received from tm
   # '{file_name_1 : [method1, method2], file_name_2: [method3]}'
   def parse_tests_to_run_from_tm tests_to_run
     # 1. split based on ],
     # 2. remove '{', '}', '[', ']', '\s'
     # result: ['file_name_1:method1,method2', 'file_name_2:method3']
     file_methods_by_colon =  tests_to_run.split(/\]\s*,/).map { |r| r.gsub(/[\}|\{|\[|\]|\s]/,'') }

     # 1. split by ':' and then split by ',' and create a hash
     # result {'file_name_1' => ['method1', 'method2'], 'file_name_2' => [method3]}
     Hash[file_methods_by_colon.map {|fm| fm.split(':')}.map {|k| [k[0], k[1].split(',')]}] 
   end
end
