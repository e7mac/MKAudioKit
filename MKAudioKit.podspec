Pod::Spec.new do |s|
  s.name             = "MKAudioKit"
  s.version          = "0.1.1"
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

  s.subspec 'Audiobus' do |audiobus|
      audiobus.source_files = 'libraries/audiobus/include/*.h'
      audiobus.vendored_libraries = 'libraries/audiobus/lib/libAudiobus.a'
      audiobus.xcconfig = { 'HEADER_SEARCH_PATHS' => "${PODS_ROOT}/#{s.name}/libraries/audiobus/include/**" }
  end

end
