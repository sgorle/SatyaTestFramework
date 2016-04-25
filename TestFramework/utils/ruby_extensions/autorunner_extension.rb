require File.expand_path(File.dirname(__FILE__) +  '/../../reporter/test/unit')
require File.expand_path(File.dirname(__FILE__)+ '/../../reporter/test/unit/autorunner')
require File.expand_path(File.dirname(__FILE__) + '/../../reporter/reporter')

class Test::Unit::AutoRunner    # :nodoc:
  def run
    @suite = @collector[self]
    $test_steps = Hash.new()
    $steps = Array.new()
    result = @runner[self] or return false
    Dir.chdir(@workdir) if @workdir
    if $results_dir
      FileUtils.mkdir_p($results_dir) unless File.directory?($results_dir)
      Test::Unit::UI::Reporter.new(@suite, $results_dir, @suite.name + ".rb" , :xml).run.passed?
    else
      result.run(@suite, @output_level).passed?
    end
  end
end
