#--
# Author:: Alexey Verkhovsky
# Copyright:: Copyright (c) 2004 Alexey Verkhovsky. All rights reserved.
# License:: Ruby license.

module Test::Unit::UI::Report

#--
# Formats execution results of a test/unit suite in verbose text
# TODO implement me
class TextFormatter #:nodoc:all

  def initialize(output_dir, suite_name)
    @output_dir = output_dir
    @suite_name = suite_name
  end
  
  def started(message)
    # TODO implement me
  end
  
  def test_started(message)
    # TODO implement me
  end
  
  def add_fault(message)
    # TODO implement me
  end

  def test_finished(message)
    # TODO implement me
  end
  
  def finished(message, test_output)
    # TODO implement me
  end

end # class
end # module
