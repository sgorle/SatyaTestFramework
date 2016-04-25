require File.expand_path(File.dirname(__FILE__) + '/../valid_properties')
require File.expand_path(File.dirname(__FILE__) +'/../reporter/test/unit/')
require File.expand_path(File.dirname(__FILE__) +'/../reporter/test/unit/assertions.rb')
require File.expand_path(File.dirname(__FILE__) + '/../utils/ruby_extensions/autorunner_extension')

module Test
  module Unit
    class TestCase
      
      include ValidProperties
      
      # add a class level instance variable to hold our properties hash
      class << self;
        attr_accessor :properties
      end

      # set the inheritable default values for our properties hash
      def self.inherited(subclass)
#        subclass.instance_variable_set("@properties", { :grouping => [], :restricted_environments => [],:restricted_browser => [],:services => [], :requires_isolation => false })
        subclass.instance_variable_set("@properties", { :grouping => []})
      end
    end
  end
end
