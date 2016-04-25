require 'fileutils'
require File.expand_path(File.dirname(__FILE__) + '/../../../tests/test.properties')
require File.expand_path(File.dirname(__FILE__) + '/../group_test_runner')
require File.expand_path(File.dirname(__FILE__) + '/../multi_test_runner')
require File.expand_path(File.dirname(__FILE__) + '/../../helpers/results_file_parser')
require File.expand_path(File.dirname(__FILE__) + '/../../valid_properties')
require File.expand_path(File.dirname(__FILE__) + '/../../shared/lib/framework_utils.rb')

include ResultsFileParser

# Clear all results log 
FileUtils.rm_rf(Dir.glob("#{$results_dir}/*")) if $results_dir

if $tests_run_name.eql?("") &&  $file_name.eql?("")
  $rerun_count = 0
  runner = GroupTestRunner.new($groups_to_run, $target_priority, :dry_run => $dry_run)
else
  raise "Nothing specified to run"
end

summary = summarize_results($results_dir)
summary[:body] = sort_result_summary(summary[:body]) if $sort_test_result == 'true'

File.open(File.join($results_dir, "result_summary.log"), "w") { |f| f.puts summary[:body] }
File.open(File.join($results_dir, "bottom_line.log"), "w") { |f| f.puts summary[:bottom_line] }

results = get_test_results($results_dir)
results[:fail].length + results[:error].length > 0 ? exit(10) : exit(0)
