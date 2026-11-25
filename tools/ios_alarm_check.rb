# Adds ios/AlarmCheck/AlarmCheck.swift to the Xcode project as a UI test and
# puts it in the Runner scheme, for one run of tools/ios_alarm_check.sh.
# The change is not meant to be committed: the app's project stays as it is.

require 'xcodeproj'

root = File.expand_path('..', __dir__)
path = File.join(root, 'ios', 'Runner.xcodeproj')
project = Xcodeproj::Project.open(path)
runner = project.targets.find { |target| target.name == 'Runner' } or abort 'No Runner target.'

check = project.targets.find { |target| target.name == 'AlarmCheck' }
unless check
  group = project.main_group.new_group('AlarmCheck', 'AlarmCheck')
  source = group.new_file('AlarmCheck.swift')
  check = project.new_target(:ui_test_bundle, 'AlarmCheck', :ios, '15.0', nil, :swift)
  # See tools/add_ios_alarm_target.rb: no framework by a path inside one SDK.
  check.frameworks_build_phase.files.to_a.each do |build_file|
    reference = build_file.file_ref
    build_file.remove_from_project
    reference&.remove_from_project
  end
  frameworks = project.main_group['Frameworks']
  frameworks.remove_from_project if frameworks && frameworks.recursive_children.none? { |child| child.isa == 'PBXFileReference' }
  check.source_build_phase.add_file_reference(source, true)
  check.add_dependency(runner)
  check.build_configurations.each do |configuration|
    configuration.build_settings.merge!(
      'GENERATE_INFOPLIST_FILE' => 'YES',
      'IPHONEOS_DEPLOYMENT_TARGET' => '15.0',
      'LD_RUNPATH_SEARCH_PATHS' => '$(inherited) @executable_path/Frameworks @loader_path/Frameworks',
      'PRODUCT_BUNDLE_IDENTIFIER' => 'wlaa41.github.io.flutterPro.AlarmCheck',
      'PRODUCT_NAME' => '$(TARGET_NAME)',
      'SWIFT_VERSION' => '5.0',
      'TARGETED_DEVICE_FAMILY' => '1,2',
      'TEST_TARGET_NAME' => 'Runner',
    )
  end
  project.save
end

scheme_path = File.join(Xcodeproj::XCScheme.shared_data_dir(path), 'Runner.xcscheme')
scheme = Xcodeproj::XCScheme.new(scheme_path)
listed = scheme.test_action.testables.any? do |testable|
  testable.buildable_references.any? { |reference| reference.target_name == 'AlarmCheck' }
end
unless listed
  scheme.add_test_target(check)
  scheme.save!
end
puts "Targets: #{project.targets.map(&:name).join(', ')}"
