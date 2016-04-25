require "set"

$max_concurrent_tests ||= "3"

# for custom test runs based on grouping (use with testsuites/ts_custom_run.rb - see lib/framework/valid_property_list.rb for valid groups)
# example of how this value needs to be specified: "JOBS, OMS, REGRESSION"
$groups_to_run ||= "SATYA"
$services_to_certify ||= ""
$test_module_path ||= ""

# This is supposed to execute only tests of a given priority.  Defaults to ALL.
$target_priority ||= ""

# where to write test result files
$results_dir ||= File.dirname(__FILE__) + "/../TestFramework/results"

# test run name, for artifact naming purposes
$test_run_name ||= "no_name"
$tests_run_name ||= ""
$file_name ||= ""
$test_failed_methods ||= ""
$enable_skip_list ||= "false"
$skip_list ||= {}

# Finding the list of tests under given tag
$dry_run ||= "false"

$find_duplicate_classes ||= "true"
$debug_mode ||= "true"

$expected_test_count ||= ""
