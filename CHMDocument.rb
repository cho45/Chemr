
class CHMDocument < NSDocument
	attr_reader :chm

	#- (void)makeWindowControllers
	def makeWindowControllers
		c = CHMWindowController.alloc.initWithWindowNibName("CHMDocument")
		self.addWindowController(c)
	end

	#- (BOOL)readFromURL:(NSURL *)inAbsoluteURL ofType:(NSString *)inTypeName error:(NSError **)outError
	def readFromURL_ofType_error(url, type, error)
		@chm = Chmlib::Chm.new(url.path.to_s)
#		log chm
#		r = NSURLRequest.requestWithURL CHMInternalURLProtocol.url_for(chm, chm.home)
#		@webview.mainFrame.loadRequest r
		true
	end

	#- (BOOL)writeToURL:(NSURL *)inAbsoluteURL ofType:(NSString *)inTypeName error:(NSError **)outError
	def writeToURL_ofType_error(url, type, error)
		false
	end

	#- (void)windowControllerDidLoadWindowNib:(NSWindowController *)windowController
	def windowControllerDidLoadWindowNib(cont)
		log "wCDLWN", cont
	end

#	def dataRepresentationOfType(aType)
#	end
#
#	def loadDataRepresentation_ofType(data, aType)
#	end

#	def displayName
#	end
	def windowControllerWillLoadNib(cont)
		log cont
	end

	def winwowNibName
		"CHMDocument"
	end
end


class CHMWindowController < NSWindowController
	ib_outlet :webview

	def windowDidLoad
		chm = self.document.chm
		r = NSURLRequest.requestWithURL CHMInternalURLProtocol.url_for(chm, chm.home)
		@webview.mainFrame.loadRequest r
	end
end
