Pod::Spec.new do |s|
  s.name             = "MKAudioKit"
  s.version          = "1.0.0"
  s.summary          = "A set of all the audio utility classes and extensions used in our iOS projects."
  s.license          = 'MIT'
  s.homepage           = 'http://www.e7mac.com'
  s.author           = { "e7mac" => "mayank.ot@gmail.com" }
  s.source           = { :git => "https://github.com/e7mac/MKAudioKit.git", :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/e7mac'

  s.platform     = :ios, '5.0'
  s.requires_arc = true

  s.source_files = 'Classes/**/*'
  # s.resources = 'Assets/**/*'
  s.framework    = 'QuartzCore'
  s.framework    = 'AudioToolbox'
  s.framework    = 'Accelerate'

  s.subspec 'Audiobus' do |audiobus|
      version = '1.0.2.5'
      audiobus.source_files = 'libraries/audiobus/' + version + '/include/*.h'
      audiobus.vendored_libraries = 'libraries/audiobus/' + version + '/lib/libAudiobus.a'
      audiobus.xcconfig = { 'HEADER_SEARCH_PATHS' => "${PODS_ROOT}/libraries/audiobus/' + version + '/include/**" }
  end

end
