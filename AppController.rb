require 'osx/cocoa'
include OSX

class CHMInternalURLProtocol < NSURLProtocol
	#+ (void)registerContainer:(CHMContainer *)container;
	#+ (void)unregisterContainer:(CHMContainer *)container;
	#+ (CHMContainer *)containerForUniqueId:(NSString *)uniqueId;
	#+ (NSURL *)URLWithPath:(NSString *)path inContainer:(CHMContainer *)container;

	SCHEME = "chm-internal"

	def self.url_for(doc, path)
		# TODO: weak ref
		url = "#{SCHEME}://#{doc.object_id}#{path}"
		NSURL.URLWithString_relativeToURL(url, "#{SCHEME}://#{doc.object_id}/")
	end

	# protocol

	#+ (BOOL)canHandleURL:(NSURL *)anURL;
	def self.canHandleURL(url)
		log url
		url.scheme == SCHEME
	end

	#+ (BOOL)canInitWithRequest:(NSURLRequest *)request
	def self.canInitWithRequest(req)
		log req
		canHandleURL(req.URL)
	end

	#+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
	def self.canonicalRequestForRequest(req)
		log req
		req
	end

	#-(NSURLRequest *)request
#	def request
#		super_request
#	end

	#-(void)startLoading
	def startLoading
		log "startLoading"
		url = request.URL
		log url.host
		log url.path
		chm = ObjectSpace._id2ref(url.host.to_s.to_i)
		log chm

		text = chm.retrieve_object(url.path.to_s)
		# data = NSData.dataWithBytesNoCopy_length(text, text.length)
		data = NSData.dataWithBytes_length(text, text.length)

		response = NSURLResponse.alloc.objc_send(
			:initWithURL, url,
			:MIMEType, "application/octet-stream",
			:expectedContentLength, data.length,
			:textEncodingName, nil
		)
		self.client.objc_send(
			:URLProtocol, self,
			:didReceiveResponse, response,
			:cacheStoragePolicy, NSURLCacheStorageNotAllowed
		)
		self.client.URLProtocol_didLoadData(self, data);
		self.client.URLProtocolDidFinishLoading(self);
	end

	#-(void)stopLoading
	def stopLoading
		log "stopLoading"
	end

	#-(NSCachedURLResponse *)cachedResponse

end

require "chm"
class AppController < NSObject
	ib_outlets :webview


	ib_action :open do |sender|
	end

	ib_action :close do |sender|
	end

	def awakeFromNib
	end

	def applicationWillFinishLaunching(n)
		r = NSURLProtocol.registerClass CHMInternalURLProtocol
		log "Register: #{r}"

		chm = Chmlib::Chm.new("/Users/cho45/tmp/ruby-refm-rdp-1.9.0-ja-htmlhelp_css/rubymanjp.chm")
		log chm
		r = NSURLRequest.requestWithURL CHMInternalURLProtocol.url_for(chm, chm.home)
		@webview.mainFrame.loadRequest r
	end

	def applicationWillTerminate(n)
		NSURLProtocol.unregisterClass CHMInternalURLProtocol
		log "Unregister"
	end
end


