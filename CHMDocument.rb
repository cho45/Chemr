#!rake ;#

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

	def displayName
		dc = NSDocumentController.sharedDocumentController
		i = dc.documents.index(self) + 1
		cmd = [8984].pack("U")
		"#{cmd}#{i}| #{@chm.title}"
	end

	def windowControllerWillLoadNib(cont)
		log cont
	end

	def winwowNibName
		"CHMDocument"
	end
end

class MySearchWindow < NSWindow

	def sendEvent(e)
		if e.oc_type == NSKeyDown
			return if delegate.process_keybinds(e)
		end
		super_sendEvent(e)
	end

end


class CHMWindowController < NSWindowController
	ib_outlet :webview
	ib_outlet :list
	ib_outlet :drawer
	ib_outlet :search

	def windowDidLoad
		@chm = self.document.chm
		browse @chm.home
		@now = @index = @chm.index.to_a.sort_by {|k,v| k} # cache
		@list.setDataSource(self)
		@list.setDoubleAction("clicked_")
		@list.setAction("clicked_")
		@search.setDelegate(self)
		@drawer.open
	end

	# Tableview
	def numberOfRowsInTableView(table)
		@now.length
	end

	def tableView_objectValueForTableColumn_row(table, column, row)
		@now[row][0]
	end

#	def tableView_setObjectValue_forTableColumn_row(table, value, column, row)
#	end

	def tableView_willDisplayCell_forTableColumn_row(table, cell, column, row)
#		case column.identifier.to_s
#		when 'regexp'
#		when 'color'
#			_, r, g, b = */(..)(..)(..)$/.match(cell.stringValue.to_s).to_a.map{|i| i.to_i(16) / 255.0 }
#			color = NSColor.colorWithCalibratedRed_green_blue_alpha(r, g, b, 1)
#			cell.setDrawsBackground(true)
#			cell.setTextColor(color)
#			cell.setBackgroundColor(NSColor.blackColor)
#		when 'hilight'
#		end
	end

	def textShouldBeginEditing(text)
		true
	end

	def textShouldEndEditing(text)
		true
	end

	def acceptsFirstResponder
		true
	end

	def controlTextDidChange(anot)
		filtering @search.stringValue
		@list.selectRowIndexes_byExtendingSelection(NSIndexSet.alloc.initWithIndex(0), false)
	end

	def controlTextDidEndEditing(anot)
		log "end #{@now.first.inspect}"
	end

	def jumpToCurrent(sender)
		unless @now.length.zero?
			#browse @now.first[1].first
			clicked(sender)
		end
	end

	def filtering(str)
		str = str.to_s
		if str =~ /[A-Z]/
			r = /^#{str}/
		else
			r = /^#{str}/i
		end
		@now = @index.select {|k,v|
			k =~ r
		}.sort_by {|k,v| k }
		@list.reloadData
	end

	def clicked(sender)
		browse @now[@list.selectedRow][1].first
	end

	def browse(path)
		if path
			path = "/#{path}" unless path[0] == ?/
			h = @webview.stringByEvaluatingJavaScriptFromString("location.pathname+location.hash")
			unless path == h
				r = NSURLRequest.requestWithURL CHMInternalURLProtocol.url_for(@chm, path)
				@webview.mainFrame.loadRequest r
			end
		end
	end

	def completion(sender)
		# not implemented yet
	end

	# from menu
	def searchActivate(sender)
		log "activate"
		@search.window.makeFirstResponder(@search)
	end

	def nextCandidate(sender)
		if @list.selectedRow <= @now.size
			@list.selectRowIndexes_byExtendingSelection(NSIndexSet.alloc.initWithIndex(@list.selectedRow+1), false)
			clicked(nil)
		end
	end

	def prevCandidate(sender)
		if @list.selectedRow > 0
			@list.selectRowIndexes_byExtendingSelection(NSIndexSet.alloc.initWithIndex(@list.selectedRow-1), false)
			clicked(nil)
		end
	end

	# from MySearchWindow

	def process_keybinds(e)
		key = key_string(e)
		log "keyDown (#{e.characters}:#{e.charactersIgnoringModifiers}) -> '#{key}'"
		keybinds = {
			"C-j" => self.method(:nextCandidate),
			"C-n" => self.method(:nextCandidate),
			"C-k" => self.method(:prevCandidate),
			"C-p" => self.method(:prevCandidate),
			"\r"  => self.method(:jumpToCurrent),
			"\t"  => self.method(:completion),
			" "   => Proc.new {|s|
				@webview.stringByEvaluatingJavaScriptFromString <<-JS
					window.scrollBy(0, 200);
				JS
			},
			"C-u" => Proc.new {|s|
				@search.stringValue = ""
			},
			"G-[" => Proc.new {|s|
				@webview.goBack
			},
			"G-]" => Proc.new {|s|
				@webview.goForward
			},
			"G-F" => Proc.new {|s|
				@webview.performFindPanelAction(self)
			},
			"G-=" => Proc.new {|s|
				@webview.makeTextLarger(self)
			},
			"G--" => Proc.new {|s|
				@webview.makeTextSmaller(self)
			},
		}
		(1..9).each do |i|
			keybinds["G-#{i}"] = Proc.new {|s|
				dc = NSDocumentController.sharedDocumentController
				if dc.documents[i-1]
					log(dc.documents[i-1].windowControllers)
					dc.documents[i-1].windowControllers.first.showWindow(self)
				end
			}
		end
		if keybinds.key?(key)
			keybinds[key].call(self)
			true
		else
			false
		end
	end

	def key_string(e)
		key = ""
		m = e.modifierFlags
		key << "S-" if m & NSShiftKeyMask > 0
		key << "C-" if m & NSControlKeyMask > 0
		key << "M-" if m & NSAlternateKeyMask > 0
		key << "G-" if m & NSCommandKeyMask > 0 # TODO
		key << e.charactersIgnoringModifiers.to_s
		key
	end

	# webview policyDelegate
	def webView_decidePolicyForNavigationAction_request_frame_decisionListener(
		sender,
		actionInformation,
		request,
		frame,
		listener
	)

		if CHMInternalURLProtocol.canHandleURL(request.URL)
			listener.use
		else
			NSWorkspace.sharedWorkspace.openURL(request.URL)
			listener.ignore
		end
	end

	def webView_decidePolicyForNewWindowAction_request_newFrameName_decisionListener(
		sender,
		actionInformation,
		request,
		frameName,
		listener
	)
		if CHMInternalURLProtocol.canHandleURL(request.URL)
			listener.use
		else
			NSWorkspace.sharedWorkspace.openURL(request.URL)
			listener.ignore
		end
	end


end
