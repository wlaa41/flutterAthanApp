# Adds the AthanAlarm extension to ios/Runner.xcodeproj, and puts the iPhone
# alarm sounds in the app bundle. It is how the project file got the target,
# kept so the step can be read and repeated: Xcode is not needed.
#
#   gem install xcodeproj
#   ruby tools/add_ios_alarm_target.rb
#
# Run it again after adding a recitation with an iPhone excerpt
# (asset/<name>_short.wav): it only adds what is missing.

require 'xcodeproj'

root = File.expand_path('..', __dir__)
project = Xcodeproj::Project.open(File.join(root, 'ios', 'Runner.xcodeproj'))
runner = project.targets.find { |target| target.name == 'Runner' } or abort 'No Runner target.'

EXTENSION = 'AthanAlarm'
BUNDLE_ID = 'wlaa41.github.io.flutterPro.AthanAlarm'

extension = project.targets.find { |target| target.name == EXTENSION }
unless extension
  group = project.main_group.new_group(EXTENSION, EXTENSION)
  shared = group.new_file('AthanAlarmKit.swift')
  widget = group.new_file('AthanAlarmWidget.swift')
  group.new_file('Info.plist')
  settings_file = group.new_file('AthanAlarm.xcconfig')

  extension = project.new_target(:app_extension, EXTENSION, :ios, '26.0', nil, :swift)
  # new_target links Foundation by a path inside one SDK version. Swift links
  # what the sources import, so the reference is only a way to break later.
  extension.frameworks_build_phase.files.to_a.each do |build_file|
    reference = build_file.file_ref
    build_file.remove_from_project
    reference&.remove_from_project
  end
  frameworks = project.main_group['Frameworks']
  frameworks.remove_from_project if frameworks && frameworks.recursive_children.none? { |child| child.isa == 'PBXFileReference' }

  extension.source_build_phase.add_file_reference(shared, true)
  extension.source_build_phase.add_file_reference(widget, true)
  extension.build_configurations.each do |configuration|
    configuration.base_configuration_reference = settings_file
    configuration.build_settings.merge!(
      'APPLICATION_EXTENSION_API_ONLY' => 'YES',
      'CURRENT_PROJECT_VERSION' => '$(FLUTTER_BUILD_NUMBER)',
      'ENABLE_BITCODE' => 'NO',
      'GENERATE_INFOPLIST_FILE' => 'NO',
      'INFOPLIST_FILE' => "#{EXTENSION}/Info.plist",
      'IPHONEOS_DEPLOYMENT_TARGET' => '26.0',
      'LD_RUNPATH_SEARCH_PATHS' => '$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks',
      'MARKETING_VERSION' => '$(FLUTTER_BUILD_NAME)',
      'PRODUCT_BUNDLE_IDENTIFIER' => BUNDLE_ID,
      'PRODUCT_NAME' => '$(TARGET_NAME)',
      'SKIP_INSTALL' => 'YES',
      'SWIFT_VERSION' => '5.0',
      'TARGETED_DEVICE_FAMILY' => '1,2',
    )
    configuration.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone' if configuration.name == 'Debug'
  end

  # The app runs the same alarm code, builds the extension first and carries it.
  runner.source_build_phase.add_file_reference(shared, true)
  runner.add_dependency(extension)
  embed = runner.new_copy_files_build_phase('Embed Foundation Extensions')
  embed.symbol_dst_subfolder_spec = :plug_ins
  embed.add_file_reference(extension.product_reference, true).settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
  # Before Flutter's Thin Binary script, or Xcode reports a build cycle.
  thin = runner.build_phases.find { |phase| phase.respond_to?(:name) && phase.name == 'Thin Binary' }
  runner.build_phases.move(embed, runner.build_phases.index(thin)) if thin
end

# AlarmKit plays a named sound from the app bundle. The excerpts are Flutter
# assets, which sit deeper, so each one is also copied to the bundle's top.
sounds = project.main_group['AlarmSounds'] || project.main_group.new_group('AlarmSounds', '../asset')
Dir[File.join(root, 'asset', '*_short.wav')].sort.each do |path|
  name = File.basename(path)
  next if sounds.files.any? { |file| file.path == name }
  reference = sounds.new_file(name)
  reference.last_known_file_type = 'audio.wav'
  runner.resources_build_phase.add_file_reference(reference, true)
end

project.save
puts "Targets: #{project.targets.map(&:name).join(', ')}"
puts "Alarm sounds in the bundle: #{sounds.files.size}"
