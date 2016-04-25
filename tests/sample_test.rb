
require File.expand_path(File.dirname(__FILE__) + '/../TestFramework/base/testcase.rb')

class SampleTest < Test::Unit::TestCase
  @properties[:grouping] = [SATYA]
  @properties[:priority] = [HIGH]
  @properties[:tcid] = [12345]
  def setup
    puts "Setup 11111111"
  end
  def test_add_integers
    a = 4
    b = 5
    c =a+b
    assert_equal(9, c, "wrong sum")  
  end
  
  def test_subtract_itegers
    a = 4
    b = 5
    c =a-b
    assert_equal(-1, c, "wrong subtraction")  
  end
  
  def test_multiple
    self.multiple
  end
  
  def multiple
    a = 4
    b = 5
    c =a*b
    assert_equal(20, c, "wrong multiplication") 
  end
  def teardown
    puts "Teardown 222222222"
  end
end
