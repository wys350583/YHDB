Pod::Spec.new do |s|
s.name             = "YHDB"
s.version          = "0.0.1"
s.summary          = "Package based on fmdb,used to conveniently call database operation."
s.description      = Package based on fmdb,used to conveniently call database operation.
s.homepage         = "https://github.com/wyhazq/YHDB"  
# s.screenshots      = "www.example.com/screenshots_1", "www.example.com/screenshots_2"  
s.license          = 'MIT'  
s.author           = { "wyh" => "443265447@qq.com" }  
s.source           = { :git => "https://github.com/wyhazq/YHDB.git", :tag => s.version.to_s }  
# s.social_media_url = 'https://twitter.com/NAME' 
s.platform     = :ios, '6.0'
# s.ios.deployment_target = '6.0'
# s.osx.deployment_target = '10.7'
s.requires_arc = true
s.source_files = 'YHDB*.h'
s.frameworks = 'Foundation'