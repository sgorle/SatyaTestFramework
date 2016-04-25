 require File.expand_path(File.dirname(__FILE__) + '/../TestFramework/base/testcase.rb')
class Sample2Test < Test::Unit::TestCase
  @properties[:grouping] = [SATYA, HAL]
  @properties[:priority] = [MEDIUM]
  @properties[:tcid] = [12345]
  def test_sample1
    assert_equal("test1", "test1")
  end
  
  def test_sample2
    assert_equal("test2", "test2")
  end
  
end