
require "pathname"
require "yaml"

def mkchmbundle(bundle_name, title, home="/index.html", keywords=[], toc={})
	root = Pathname.new(bundle_name)
	root.rmtree rescue nil
	root.mkpath

	contents  = root + "Contents"
	contents.mkpath
	(contents + "PkgInfo").open("w") {|f| f << "BNDL????" }
	(contents + "Info.plist").open("w") {|f| f << <<-InfoPlist.gsub(/^\t{2}/, "") }
		<?xml version="1.0" encoding="UTF-8"?>
		<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
		<plist version="1.0">
		<dict>
				<key>CFBundleName</key>
				<string></string>
				<key>CFBundleInfoDictionaryVersion</key>
				<string>6.0</string>
				<key>CFBundlePackageType</key>
				<string>BNDL</string>
				<key>CFBundleSignature</key>
				<string>????</string>

				<key>CHMTitle</key>
				<string>#{title}</string>
				<key>CHMHome</key>
				<string>#{home}</string>
				<key>CHMKeyword</key>
				<string>/keyword.yaml</string>
				<key>CHMTOC</key>
				<string>/toc.yaml</string>
		</dict>
		</plist>
	InfoPlist

	resources = contents + "Resources"
	resources.mkpath

	(resources + "keyword.yaml").open("w") {|f| f << keywords.to_yaml }
	(resources + "toc.yaml").open("w") {|f| f << toc.to_yaml }

	[root, resources]
end

if $0 == __FILE__
	mkchmbundle("Test.chm", "Test", "/index.html", ["hoge", ["aaaa.html"]], {})
end
