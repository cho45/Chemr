require 'osx/cocoa'
include OSX

require "uri"

class CHMInternalURLProtocol < NSURLProtocol
	#+ (void)registerContainer:(CHMContainer *)container;
	#+ (void)unregisterContainer:(CHMContainer *)container;
	#+ (CHMContainer *)containerForUniqueId:(NSString *)uniqueId;
	#+ (NSURL *)URLWithPath:(NSString *)path inContainer:(CHMContainer *)container;

	SCHEME = "chm-internal"

	def self.url_for(doc, path)
		path.gsub!(/\\/, "/")
		path = Pathname.new(path).cleanpath.to_s
		url = URI("#{SCHEME}://obj:#{doc.object_id}/") + path
		# log url
		NSURL.URLWithString_relativeToURL(url.to_s, "#{SCHEME}://obj:#{doc.object_id}/")
	end

	# protocol

	#+ (BOOL)canHandleURL:(NSURL *)anURL;
	def self.canHandleURL(url)
		# log "canhandle #{url}"
		return false unless url
		url.scheme == SCHEME
	end

	#+ (BOOL)canInitWithRequest:(NSURLRequest *)request
	def self.canInitWithRequest(req)
		# log "canInitWithRequest: #{req.URL.absoluteString}"
		canHandleURL(req.URL)
	end

	#+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
	def self.canonicalRequestForRequest(req)
		req
	end

	#-(NSURLRequest *)request
#	def request
#		super_request
#	end

	#-(void)startLoading
	def startLoading
		log "startLoading #{request.URL.absoluteString}"
		url = request.URL
		chm = ObjectSpace._id2ref(url.port.to_s.to_i)

		log url.path.to_s
		text = url.parameterString ? chm.retrieve_object("#{url.path};#{url.parameterString}") \
		                           : chm.retrieve_object("#{url.path}")
		raise "empty" if text.empty?
		data = NSData.dataWithBytes_length(text, text.length)

		response = NSURLResponse.alloc.objc_send(
			:initWithURL, url,
			:MIMEType, "text/html",
			:expectedContentLength, data.length,
			:textEncodingName, nil
		)
		self.client.objc_send(
			:URLProtocol, self,
			:didReceiveResponse, response,
			:cacheStoragePolicy, NSURLCacheStorageNotAllowed
		)
		self.client.URLProtocol_didLoadData(self, data)
		self.client.URLProtocolDidFinishLoading(self)
	rescue => e
		log "#{e}->#{url.path.to_s}"
		self.client.objc_send(
			:URLProtocol, self,
			:didFailWithError, NSError.objc_send(
				:errorWithDomain, NSURLErrorDomain,
				:code, 0,
				:userInfo, nil
			)
		)
	end

	#-(void)stopLoading
	def stopLoading
		# log "stopLoading"
	end

	#-(NSCachedURLResponse *)cachedResponse

end

require "chm"
require "pathname"

class AppController < NSObject

	ib_action :about do |sender|
		path = Pathname.new NSBundle.mainBundle.resourcePath.to_s
		OSX::NSApp.orderFrontStandardAboutPanelWithOptions({
		#	'Credits' => nil,
			'Copyright'          => 'GPL by cho45(さとう) see README/COPYING',
			'Version'            => (File.read(path + 'VERSION') rescue "0/Unpackaged Test"),
			'ApplicationVersion' => '0'
		})
	end

	def awakeFromNib
	end

	def applicationWillFinishLaunching(n)
		r = NSURLProtocol.registerClass CHMInternalURLProtocol
		log "Register: #{r}"

		# "/Users/cho45/tmp/ruby-refm-rdp-1.9.0-ja-htmlhelp_css/rubymanjp.chm"
	end

	def applicationWillTerminate(n)
		NSURLProtocol.unregisterClass CHMInternalURLProtocol
		log "Unregister"
	end

end


