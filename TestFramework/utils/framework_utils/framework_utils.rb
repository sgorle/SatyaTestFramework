# Utility to count test methods in a test script and return the count.
# Author: Praveena

class FrameworkUtils

  attr_reader :count

  def get_test_count(files_to_run)
    @count = 0
    files_to_run.sort.each do |f|
      require f
      class_name = get_test_class_name(f)
      if class_name != nil
        test_class = Kernel.const_get(class_name)
        test_names = test_class.instance_methods.grep(/^test_/)
        @count += test_names.size
      end
    end

    puts "\nFound #{count} test methods :"
    return @count
  end

  def get_test_class_name(file_name)
    file_name += '.rb' unless file_name =~ /\.rb$/

    # make sure file gets closed; using closure/block File.read.each is a recommended approach
    # http://stackoverflow.com/questions/1727217/file-open-open-and-io-foreach-in-ruby-what-is-the-difference
     begin
       File.read(file_name).each_line { |line| return $1.strip if line =~ /class\ (.*)<\ ?Test/ }
       rescue Exception => e
         puts file_name
         puts "Exception caught: #{e.message}"
     end
    return nil # if test class not found
  end
end