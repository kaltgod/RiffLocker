#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
#
Pod::Spec.new do |s|
  s.name             = 'audio_analyzer'
  s.version          = '0.0.1'
  s.summary          = 'A C++ audio analyzer library using Aubio.'
  s.description      = <<-DESC
A new flutter plugin project.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'

  # Aubio sources and wrapper
  # We manually list the sources we want to compile OR use a script.
  # Since we used CMake FetchContent for Android, for iOS/CocoaPods we can also try to use a script
  # or simpler: Just point to the C++ files in ../native_lib if possible.
  
  # However, pointing to files outside the podspec directory is tricky in CocoaPods.
  # Strategy: We'll make this podspec wrap the native build.
  # ACTUALLY, simpler approach for Flutter + FFI: 
  # Use the standard Flutter FFI plugin template approach which uses CMake or standard Xcode.
  
  # But since we are manually editing an existing App, not a Plugin:
  # We will define a Pod that builds the C++ code.
  
  s.platform = :ios, '11.0'

  # Compiler flags
  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES', 
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'OTHER_CFLAGS' => '-DHAVE_ACCELERATE=1',
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}/../native_lib/include" "${PODS_TARGET_SRCROOT}/../native_lib/aubio/src"'
  }
  
  s.library = 'c++'
  s.frameworks = 'Accelerate', 'AudioToolbox'

  # We need to tell CocoaPods where to find the source files. 
  # They are in ../native_lib. 
  # Note: CocoaPods is picky about parent directories. 
  # We might need to symlink or just use the prepare_command to copy them?
  # Or just use the 'source_files' with .. path if allowed (it is strictly not, but 'preserve_paths' might help).
  
  # Alternative: 'Script Phase' in Xcode is easier to just run CMake? 
  # No, let's try to reference them directly. 
  # Many Flutter plugins do s.source_files = '../src/**/*'
  
  s.source_files = '../native_lib/src/**/*.{c,cpp,h}', '../native_lib/include/**/*.{h}'
  
  # We need the Aubio source code. 
  # Since we used FetchContent in CMake, we don't effectively have the aubio source checked in 
  # unless we ran CMake or have it as submodule.
  # User requirements said "Downloads and builds Aubio...".
  # So for iOS, we also need to fetch it.
  
  s.prepare_command = <<-CMD
    # Download Aubio if not present (simple version of what FetchContent does)
    if [ ! -d "../native_lib/aubio" ]; then
      git clone --depth 1 --branch 0.4.9 https://github.com/aubio/aubio.git ../native_lib/aubio
    fi
  CMD

  s.source_files = '../native_lib/src/**/*.{c,cpp,h}', '../native_lib/include/**/*.{h}', '../native_lib/aubio/src/**/*.{c,h}'
  
  s.dependency 'Flutter'
end
