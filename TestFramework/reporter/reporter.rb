#--
# Author:: Alexey Verkhovsky
# Copyright:: Copyright (c) 2004 Alexey Verkhovsky. All rights reserved.
# License:: Ruby license.
 
require 'pathname'
require 'delegate'
require File.dirname(__FILE__) + '/test/unit/ui/console/testrunner'
require File.dirname(__FILE__) + '/test/unit/ui/testrunnerutilities'
require File.dirname(__FILE__) + '/test/unit/ui/testrunnermediator'
require 'stringio'
require File.dirname(__FILE__) + '/htmlformatter'
require File.dirname(__FILE__) + '/xmlformatter'
require File.dirname(__FILE__) + '/textformatter'

module Test::Unit::UI

      class StreamReplicator
        def initialize(*streams)
          @streams = streams
        end 
        
        def write(s)
          method_missing('write', s)
        end  
        
        def method_missing(name, *args, &block)
          @streams.each { |stream| stream.send(name, *args, &block) }
        end
      end

      # Runs a Test::Unit::TestSuite and reports results in specified format to specified directory
      #
      # See README[link:files/README.html] for the overview and usage details
      class Reporter
        
        @@output_level = Test::Unit::UI::NORMAL

        def initialize(suite, output_dir, test_file_path, format = :junit, runner_class = Test::Unit::UI::Console::TestRunner) #:notnew:
          @test_file_path = test_file_path
          @output_dir = output_dir
          @suite = suite
          @formatter = createFormatter(output_dir, suite, format)
          @io_copy = StringIO.new
          @runner = runner_class.new(suite, @@output_level, StreamReplicator.new(@io_copy, STDOUT))
          @runner.instance_eval <<-EOL
            alias original_start start
            def start
              setup_mediator
              attach_to_mediator
              yield @mediator
              return start_mediator
            end
          EOL
        end
        
        def run
          @runner.start do |mediator|
            add_listeners(mediator)
          end
        end
        
        # mediator methods go here
        
        def add_fault(fault)
          @formatter.add_fault(fault)
        end
        
        def started(result)
          @formatter.started(result)
        end
        
        def finished(duration)
          @io_copy.rewind
          @formatter.finished(duration, @io_copy.readlines.join)
        end
        
        def test_started(name)
          @formatter.test_started(name)
        end
        
        def test_finished(name)
          class_name = get_test_class_name(@suite.name)      
          steps = $test_steps[class_name]
          @formatter.test_finished(name, steps)
          $test_steps.delete(class_name)
        end

        def get_test_class_name(file_name)
          if(file_name=~/\//)
            file_name += ".rb" unless file_name =~ /\.rb$/
            # make sure file gets closed; using closure/block File.read.each is a recommended approach
            # http://stackoverflow.com/questions/1727217/file-open-open-and-io-foreach-in-ruby-what-is-the-difference
            File.read(file_name).each_line { |line| return $1.strip if line =~ /class\ (.*)<\ ?Test/ }
            return nil # if test class not found
          else
            return file_name.gsub(/^.*\(/,"").gsub("\)","")
          end

          end
        
        private
        
        def createFormatter(output_dir, suite, format)
          class_name = get_test_class_name(@suite.name)
          owner = ""
          dev_owner = ""
          if(!class_name.nil?)
            test_class = Kernel.const_get(class_name) 
            testcase_id = test_class.properties[:tcid] 
            tcids = Hash.new
            # Create hash to map test name with tcid if tcid and test/s exists in suite 
            if(test_class.properties[:owner].nil?)
              owner = ""
            else
              owner = test_class.properties[:owner]
            end 
           dev_owner = test_class.properties[:dev_owner] if !test_class.properties[:dev_owner].nil?
            if(test_class.properties[:services].nil?)
              services = ""
            else
              services = test_class.properties[:services]
            end 
          end
          case format
          when :html
            Test::Unit::UI::Report::HtmlFormatter.new(@output_dir, @suite.name, owner, dev_owner)
          when :xml
            Test::Unit::UI::Report::XmlFormatter.new(@output_dir, @suite.name, owner, dev_owner, services, tcids, @test_file_path)
          when :verbose_text
            Test::Unit::UI::Report::TextFormatter.new(@output_dir, @suite.name, owner, dev_owner)
          else
            raise "Unsupported format: #{format}"
          end
        end

        def add_listeners(mediator) #:nodoc:
          mediator.add_listener(Test::Unit::TestResult::FAULT, &self.method(:add_fault))
          mediator.add_listener(Test::Unit::UI::TestRunnerMediator::STARTED, &self.method(:started))
          mediator.add_listener(Test::Unit::UI::TestRunnerMediator::FINISHED, &self.method(:finished))
          mediator.add_listener(Test::Unit::TestCase::STARTED, &self.method(:test_started))
          mediator.add_listener(Test::Unit::TestCase::FINISHED, &self.method(:test_finished))
        end

        def validate_output_dir(dir)
          raise 'Reports path not specified' unless dir
          path = Pathname.new(dir)
          raise IOError.new("Output path '#{path}' not found") unless dir.exist?
          raise IOError.new("Output path '#{path}' is not a directory") unless dir.directory?
          raise IOError.new("Output path '#{path}' is not writable") unless dir.writable?
        end
        
        def get_tcids_by_testname(test_names, testcase_id)
            count = 0
            tcids = Hash.new            
            # Cover case when multiple tcids are mapped to single test method
            if((@test_names.size == 1) && (@test_names.size  < testcase_id.size))
                tcids[@test_names[0]] = testcase_id.join(",")
            else
              @test_names.each do |test_name|
                # Cover case when there are more test methods than provided tcids
                if(@test_names.size  > testcase_id.size)
                  tcids[test_name] = testcase_id.join(",")
                else
                # Set tcid in hash  
                tcids[test_name] = testcase_id[count].to_s()
                count = count + 1
                end
              end  
            end
          return tcids
        end

      end # class Reporter

end # module Test::Unit::UI::Reporter
