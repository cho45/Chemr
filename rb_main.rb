#
#  rb_main.rb
#  Chemr
#
#  Created by さとう on Tue Oct 23 2007.
#  Copyright (c) 2007 «ORGANIZATIONNAME». All rights reserved.
#

require 'osx/cocoa'

OSX.require_framework "/System/Library/Frameworks/WebKit.framework"

def log(*args)
	args.each do |m|
		OSX.NSLog m.inspect
	end
end

def _(key)
	NSLocalizedString(key, '').to_s
end

def rb_main_init
	path = OSX::NSBundle.mainBundle.resourcePath.fileSystemRepresentation
	rbfiles = Dir.entries(path).select {|x| /\.rb\z/ =~ x}
	rbfiles -= [ File.basename(__FILE__) ]
	rbfiles.each do |path|
		require( File.basename(path) )
	end
end

if $0 == __FILE__ then
	rb_main_init
	OSX.NSApplicationMain(0, nil)
end
