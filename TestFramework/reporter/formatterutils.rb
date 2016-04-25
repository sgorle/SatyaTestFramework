#--
# Author:: Alexey Verkhovsky
# Copyright:: Copyright (c) 2004 Alexey Verkhovsky. All rights reserved.
# License:: Ruby license.

require 'fileutils'

#--
# Some utility functions used by various formatter implementations
# Refactor into AbstractFormatter when if/when there will be enmnogh common
# behavior to justify it
module Test::Unit::UI::Report #:nodoc:

  def get_class_and_name(full_test_name) #:nodoc:
 	# This regexp will match strings like 'some characters(some more characters)'. This is how
	# test/unit names tests, part before the parentheses is the name of test method, part inside
	# parentheses is name of test class
	match_data = /^([^\(]*)(\([^\)]*\)$)/.match(full_test_name)
	if match_data
	  # [1..-2] here removes the round brackets
	  test_class = match_data[2][1..-2]
	  if test_class == '' then test_class = 'Ruby test suite ' end
	  test_name = match_data[1]
	else
	  test_class = 'Ruby test'
	  test_name = full_test_name
	end
	[test_class, test_name]
  end
  
  def check_directory(dir) #:nodoc:
    raise IOError.new("Directory not found: #{dir}") unless File.exist?(dir)
    raise IOError.new("File '#{dir}' is not a directory") unless File.directory?(dir)
  end
  
  # converts s to a useable file name by replacing all spaces, back and forward slashed to %_%
  def file_name(s)
    s.gsub(/[\s\\\/]/, '_')
  end

end
