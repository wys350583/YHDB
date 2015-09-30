Pod::Spec.new do |s|
s.name             = "YHDB"
s.version          = "0.0.1"
s.summary          = "Package based on fmdb."
s.description      = "Package based on fmdb,used to conveniently call database operation."
s.homepage         = "https://github.com/wyhazq/YHDB"  
s.license          = { :type => "MIT", :file => "LICENSE" }  
s.author           = { "wyh" => "443265447@qq.com" }  
s.source           = { :git => "https://github.com/wyhazq/YHDB.git", :tag => s.version.to_s }  
s.platform     = :ios, '6.0'
s.requires_arc = true
s.source_files = 'YHDB/*'
s.frameworks = 'Foundation'
s.subspec 'YHDB' do |sp|
    sp.requires_arc = true
    sp.dependency 'FMDB'
  end
end