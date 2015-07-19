Pod::Spec.new do |s|
  s.name             = "MKAudioKit"
  s.version          = "1.0.0"
  s.summary          = "A set of all the audio utility classes and extensions used in our iOS projects."
  s.license          = 'MIT'
  s.homepage           = 'http://www.e7mac.com'
  s.author           = { "e7mac" => "mayank.ot@gmail.com" }
  s.source           = { :git => "https://github.com/e7mac/MKAudioKit.git", :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/e7mac'

  s.platform     = :ios, '7.0'
  s.requires_arc = true


  subspecs = ['AudioController', 'Presets', 'Interaction']

  subspecs.each do |subspec|
    s.subspec subspec do |ss|
      ss.source_files = subspec + '/*'
      ss.resources = subspec + '/{assets,images,fonts,UI,audio}/*'
      s.frameworks    = 'QuartzCore', 'AudioToolbox', 'Accelerate', 'AVFoundation'
    end
  end

  s.dependency 'Audiobus'
  s.dependency 'STAlertView'
  s.dependency 'Parse'
end
