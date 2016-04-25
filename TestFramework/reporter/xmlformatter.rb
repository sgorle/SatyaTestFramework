#--
# Author:: Alexey Verkhovsky
# Copyright:: Copyright (c) 2004 Alexey Verkhovsky. All rights reserved.
# License:: Ruby license.

require 'time'
require 'rexml/document'
require File.dirname(__FILE__) + '/test/unit/failure'
require File.dirname(__FILE__) + '/test/unit/error'
require File.dirname(__FILE__) + '/formatterutils'

module Test::Unit::UI::Report

#--
# Reports execution results of a test/unit suite in XML file that
# can be converted to HTML by Ant junitreport task 
class XmlFormatter #:nodoc:all

  include Test::Unit::UI::Report

  def initialize(output_dir, suite_name,suite_owner,suite_dev_owner, services, tcids, test_file_path)
    @test_file_path = test_file_path
    @output_dir = output_dir
    @test_running = nil
    @suite_running = nil
    @suite_name = suite_name.gsub(/::/, '__')
    @owner = suite_owner
    @dev_owner = suite_dev_owner
    @tcids = tcids
    @services = services
  end

  def started(message)
    raise 'Nested test suites are not supported' if @suite_running
    @suite_running = REXML::Element.new('testsuite')
    @test_result = message

  end

  def finished(duration, test_output)
    @suite_running.add_attribute 'name', @suite_name
    @suite_running.add_attribute 'tests', @test_result.run_count
    @suite_running.add_attribute 'failures', @test_result.failure_count
    @suite_running.add_attribute 'errors', @test_result.error_count
    @suite_running.add_attribute 'time', duration
    sysout = REXML::Element.new 'system-out'
    sysout.text = REXML::CData.new escape_cdata_end(test_output)
    @suite_running.add(sysout)
    write_to_file(@suite_running)
  end

  def test_started(message)
    # message to test_started is a name of the test, e.g. testSomething(MyModule::MyTest)
    test_class, test_name = get_class_and_name(message)
    @test_running = REXML::Element.new 'testcase'
    @test_running.add_attribute 'full_name', message
    @test_running.add_attribute 'classname', test_class
    @test_running.add_attribute 'owner', @owner
    @test_running.add_attribute 'dev_owner', @dev_owner
    @test_running.add_attribute 'services', @services
    @test_running.add_attribute 'name', test_name
    @test_running.add_attribute 'file_path', @test_file_path
    @test_started = Time.now
  end

  def add_fault(fault)
    raise 'Unexpected ADD_FAULT message' unless @test_running
    # The only kind of child elements @test_running may have are problems
    test_has_problem_already = @test_running.has_elements?
    #raise 'Second ADD_FAULT message for the same test' if test_has_problem_already
  if fault.kind_of?(Test::Unit::Error)
      problem = REXML::Element.new 'error'
      problem.add_attribute 'message', fault.exception.message
      problem.add_attribute 'type', fault.exception.class
    else
      problem = REXML::Element.new 'failure'
      problem.add_attribute 'message', fault.message
      problem.add_attribute 'type', 'test/unit failure'
  end
  problem.text = REXML::CData.new escape_cdata_end(fault.long_display)
  @test_running.add problem
  end

  def test_finished(message, steps="")
    test_class, test_name = get_class_and_name(message)
    finish_time = Time.now
    steps_element = REXML::Element.new 'steps'
    if(steps.nil?)
      steps_value = ""
    else
      steps_value = steps.join("\n")
    end
    steps_element.text = REXML::CData.new escape_cdata_end(steps_value)
    @test_running.add steps_element
    raise 'Unexpected TEST_FINISHED message' unless @test_running
    if (@test_running.attribute('full_name').to_s != message)
    raise "Name of finished test '#{message}' doesn't correspond " +
             "to name of last started test '#{@test_running.attribute('full_name')}'" 
    end
    @test_running.add_attribute 'time', finish_time - @test_started
    @suite_running << @test_running
    @test_running = nil
    write_to_file(@suite_running)

  end

  def write_to_file(suite)
    out = REXML::Document.new('<?xml version="1.0" encoding="UTF-8" ?>')
    out.add @suite_running
    File.open(File.join(@output_dir, "TEST-#{file_name(@suite_name)}.xml"), 'w') do |f|
      out.write f
    end
  end

  # This method replaces the end tag of a CDATA with another string because
  # REXML::CData does not automatically escape the end tag, and if we pass "]]>" to the
  # REXML::CData constructor, it results in an error. This error hides the original
  # error thrown in xss test cases.
  def escape_cdata_end(string)
    string.gsub(']]>', ']]&gt;')
  end

end # class
end # module
