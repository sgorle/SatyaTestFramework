#--
# Author:: Alexey Verkhovsky
# Copyright:: Copyright (c) 2004 Alexey Verkhovsky. All rights reserved.
# License:: Ruby license.
 
require File.dirname(__FILE__) + '/formatterutils'

module Test::Unit::UI::Report

#--
# Reports execution results of a test/unit suite as a set of HTML files created in a 
# specified directory
class HtmlFormatter #:nodoc:all

  include Test::Unit::UI::Report

  PASS = 'Pass'
  ERROR = 'Error'
  FAILURE = 'Failure'
  
  TestRecord = Struct.new(:class_name, :test_name, :start_time, :duration, :fault)

  def initialize(output_dir, suite_name)
    @output_dir = output_dir
    @suite_name = suite_name
  end
  
  def started(message)
    @tests = {}
  end

  def test_started(full_name)
    # the arg to test_started is full name of the test, e.g. 'testSomething(MyModule::MyTest)'
    new_test = TestRecord.new
    new_test.class_name, new_test.test_name = get_class_and_name(full_name)
    new_test.start_time = Time.now
    @tests[full_name] = new_test
  end
  
  def add_fault(fault)
    @tests[fault.test_name].fault = fault
  end

  def test_finished(full_name)
    test = @tests[full_name]
    test.duration = Time.now - test.start_time
  end
  
  def finished(duration, test_output)
    analyze_results
    @summary_table = ''
    @results.each_pair { |test_class, result| write_class_report(test_class, result) }
    write_string_to_file(INDEX_HTML, 'index.html')
    write_string_to_file(STYLESHEET, 'stylesheet.css')
    write_classes_list
    write_summary(test_output)
  end

  private
  
  def analyze_results
    @results = Hash.new
    @tests.each_value { 
      |test| 
      (@results[test.class_name] ||= []) << test
    }
  end
  
  def write_classes_list
    test_classes_table = "<table width=\"100%\">\n" + @results.keys.sort.inject('') {
	    |table, class_name|
	    table + 
	      "\n" +
	      "<tr>\n" + 
	      "<td nowrap=\"nowrap\">\n" +
	      "<a target=\"classFrame\" href=\"#{make_valid_url(file_name(class_name) + '.html')}\">#{class_name}</a>\n" +
	      "</td>\n" +
	      "</tr>\n"
    } + "</table>"
    write_string_to_file(eval(CLASSES_HTML), 'classes.html')
  end
  
  def write_class_report(test_class, result)
    test_cases_count = 0
    errors_count = 0
    failures_count = 0
    total_duration = 0.0
    results_table = ""
    result.sort! { |a, b| a.test_name <=> b.test_name}
    result.each {
      |test_record|
      test_cases_count += 1
      total_duration += test_record.duration
      if test_record.fault 
        if test_record.fault.kind_of? Test::Unit::Error
          errors_count += 1
          status = ERROR
        elsif test_record.fault.kind_of? Test::Unit::Failure
          failures_count += 1
          status = FAILURE
        else
          raise "Unexpected fault type #{test_record.fault.class}"
        end
      else
        status = PASS
      end
      results_table << format_result(test_record, status)
    }
    summary_entry = eval(SUMMARY_ENTRY_HTML)
    @summary_table << summary_entry
    write_string_to_file(eval(CLASS_REPORT_HTML), "#{file_name(test_class)}.html")
  end

  def write_summary(test_output)
    if (test_output.nil? or test_output.empty?) 
      link_to_test_output = ''
    else 
      write_string_to_file(test_output, 'test_output.txt')
      link_to_test_output = '<br/><a href="./test_output.txt">Test output</a>'
    end
    
    write_string_to_file(eval(SUMMARY_HTML), 'summary.html')
  end

  def format_result(test_record, status)
    "<tr valign=\"top\" class=\"#{status}\">\n" +
    "<td>#{test_record.test_name}</td>\n" +
    "<td>#{status}</td>\n" + 
    (test_record.fault ? format_fault(test_record.fault, status) : '<td/>') +
    "<td>#{format_duration(test_record.duration)}</td>\n" + 
    "</tr>\n"
  end

  def format_fault(fault, status)
    case status
    when ERROR
      e = fault.exception
      "<td>#{e.message}<br/>\n" +
      "<br/>\n" + 
      "<code>#{e.to_s}<br/>#{e.backtrace.join('<br/>')}</code></td>\n"
    when FAILURE
      "<td>#{fault.message}<br/>\n" +
      "<br/>\n" + 
      "<code>#{fault.message}<br/>#{fault.location.join('<br/>')}</code></td>\n"
    else
      raise "Invalid fault status #{status}"
    end
  end
  
  def write_string_to_file(string, file_name)
    check_directory @output_dir
    path = File.join(@output_dir, file_name)
    File.open(path, 'w') { |ios| ios.puts string }
  end

  # makes a valid URL from a file name by substituting characters that are not allowed in URL 
  # with their %ASCII equivalents 
  def make_valid_url(file_name)
    disallowed_url_char = /[^a-zA-Z0-9\-\_\.\!\~\*\'\|]/
    file_name.gsub(disallowed_url_char) { |c| "%" + ("%02x" % c[0]) }
  end
  
  # Formats duration (which is a Float) as seconds.milliseconds, 
  # e.g. 1.12345678 is formatted as "1.123"
  def format_duration(duration)
    "%.3f" % duration
  end

  INDEX_HTML = <<-EOL
    <html>
    <head>
    <META http-equiv="Content-Type" content="text/html; charset=US-ASCII"/>
    <title>Unit Test Results.</title>
    </head>
    <frameset cols="20%,80%">
    <frame name="classListFrame" src="classes.html">
    <frame name="classFrame" src="summary.html">
    </frameset>
    <noframes>
    <h2>Frame Alert</h2>
    <p>
    This document is designed to be viewed using the frames feature. 
    If you see this message, you are using a non-frame-capable web client.
    </p>
    </noframes>
    </frameset>
    </html>
  EOL

  CLASSES_HTML = <<-EOL
    %{
    <html>
    <head>
    <META http-equiv="Content-Type" content="text/html; charset=US-ASCII"/>
    <title>All Test Classes</title>
    <link title="Style" type="text/css" rel="stylesheet" href="stylesheet.css"/>
    </head>
    <body>
    <h2>
    <a target="classFrame" href="summary.html">Summary</a>
    </h2>
    <h2>Classes</h2>
    \#{test_classes_table}
    </body>
    </html>
    }
  EOL

  PAGE_HEADER = <<-EOL
    <h1>Test Results</h1>
    <table width="100%">
    <tr>
    <td align="left"></td><td align="right">
    Designed for use with 
    <a href="http://www.ruby-doc.org/stdlib/libdoc/test/unit/rdoc/classes/Test/Unit.html">
    Ruby test/unit
    </a>
    </td>
    </tr>
    </table>
    <hr size="1">
  EOL
  
  RESULTS_TABLE_START = <<-EOL
    <table width="95%" cellspacing="2" cellpadding="5" border="0" class="details">
    <tr valign="top">
    <th width="80%">Name</th><th>Tests</th>
    <th>Errors</th>
    <th>Failures</th>
    <th nowrap="nowrap">Time (sec)</th>
    </tr>
  EOL
  
  RESULTS_TABLE_FINISH = <<-EOL
    </table>
  EOL

  CLASS_REPORT_HTML = <<-EOL
    %{
    <html xmlns:stringutils="xalan://org.apache.tools.ant.util.StringUtils">
    <head>
    <META http-equiv="Content-Type" content="text/html; charset=US-ASCII"/>
    <title>Unit Test Results: FailingTest</title>
    <link title="Style" type="text/css" rel="stylesheet" href="stylesheet.css"/>
    </head>
    <body>
    \#{PAGE_HEADER}
    <h3>\#{test_class}</h3>
    \#{RESULTS_TABLE_START}
    \#{summary_entry}
    \#{RESULTS_TABLE_FINISH}
    <h2>Tests</h2>
    <table width="95%" cellspacing="2" cellpadding="5" border="0" class="details">
    <tr valign="top">
    <th>Name</th><th>Status</th><th width="80%">Type</th><th nowrap="nowrap">Time (sec)</th>
    </tr>
    \#{results_table}
    </table>
    </body>
    </html>
    }
  EOL

  SUMMARY_ENTRY_HTML = <<-EOL
    %{
    <tr valign="top" class="\#{errors_count > 0 ? ERROR : (failures_count > 0 ? FAILURE : PASS) }">
    <td><a href="\#{make_valid_url(test_class + '.html')}">\#{test_class}</a></td>
    <td>\#{test_cases_count}</td>
    <td>\#{errors_count}</td>
    <td>\#{failures_count}</td>
    <td>\#{format_duration(total_duration)}</td>
    </tr>
    }
  EOL
  
  SUMMARY_HTML = <<-EOL
  %{
    <html>
    <head>
    <META http-equiv="Content-Type" content="text/html; charset=US-ASCII"/>
    <link title="Style" type="text/css" rel="stylesheet" href="stylesheet.css"/>
    </head>
    <body>
    \#{PAGE_HEADER}
    <h3>Classes</h3>
    \#{RESULTS_TABLE_START}
    \#{@summary_table}
    \#{RESULTS_TABLE_FINISH}
    \#{link_to_test_output}
    </body>
    </html>
  }
  EOL
  
  STYLESHEET = <<-EOL
    body {
        font:normal 68% verdana,arial,helvetica;
        color:#000000;
    }
    table tr td, table tr th {
        font-size: 68%;
    }
    table.details tr th{
        font-weight: bold;
        text-align:left;
        background:#a6caf0;
    }
    table.details tr td{
        background:#eeeee0;
    }
  
    p {
        line-height:1.5em;
        margin-top:0.5em; margin-bottom:1.0em;
    }
    h1 {
        margin: 0px 0px 5px; font: 165% verdana,arial,helvetica
    }
    h2 {
        margin-top: 1em; margin-bottom: 0.5em; font: bold 125% verdana,arial,helvetica
    }
    h3 {
        margin-bottom: 0.5em; font: bold 115% verdana,arial,helvetica
    }
    h4 {
        margin-bottom: 0.5em; font: bold 100% verdana,arial,helvetica
    }
    h5 {
        margin-bottom: 0.5em; font: bold 100% verdana,arial,helvetica
    }
    h6 {
        margin-bottom: 0.5em; font: bold 100% verdana,arial,helvetica
    }
    .Error {
        font-weight:bold; color:red;
    }
    .Failure {
        font-weight:bold; color:purple;
    }
    .Properties {
      text-align:right;
    }
  EOL
  
end
end
