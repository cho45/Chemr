
require "uri"

class CHMWindowController < NSWindowController
	ib_outlet :webview
	ib_outlet :list
	ib_outlet :tree
	ib_outlet :drawer
	ib_outlet :search

	def windowDidLoad
		@chm = self.document.chm
		uri  = URI(self.document.fileURL.absoluteString)
		browse @chm.home
		@now = @index = @chm.index.to_a.sort_by {|k,v| k.to_s } # cache
		init_hash
		@list.setDataSource(self)
		@list.setDoubleAction("clicked_")
		@list.setAction("clicked_")

		@tree.setAction("treeclicked_")

		@search.setDelegate(self)
		@drawer.open
		searchActivate(nil)
		load_condition
	end

	KEY_LENGTH = 2
	def init_hash
		@hash = Hash.new{[]}
		@index.each do |k, v|
			key = k[0, KEY_LENGTH].downcase
			@hash[key] <<= [k, v]
		end
	end

	def windowWillClose(sender)
		save_condition
	end

	def load_condition
		category = NSUserDefaults.standardUserDefaults[:documents]
		if category
			config = category[self.document.fileURL.absoluteString]
			if config
				self.window.setFrame_display(NSRect.new(*config[:frame].to_ruby), false)
				size = @drawer.contentSize
				size.width = config[:drawer_width].to_f
				@drawer.setContentSize(size)
				@search.stringValue = config[:search]
				@search.currentEditor.setSelectedRange(NSRange.new(@search.stringValue.length, 0))
				controlTextDidChange(nil)

				browse config[:url]
			else
				config = category[:last]
				if config
					frame = self.window.frame
					frame.size = NSSize.new(*config[:frame].to_ruby[2..3])
					self.window.setFrame_display(frame, false)
					size = @drawer.contentSize
					size.width = config[:drawer_width].to_i
					@drawer.setContentSize(size)
				end
			end
		end
	end

	def save_condition
		userdef = NSUserDefaults.standardUserDefaults
		category = userdef[:documents]
		category = category ? category.to_ruby : {}
		config = {
			:frame => self.window.frame.to_a.flatten,
			:search => @search.stringValue,
			:drawer_width => @drawer.contentSize.width,
			:url => @webview.mainFrameURL,
		}
		category[self.document.fileURL.absoluteString.to_s] = config
		category['last'] = config
		userdef[:documents] = category
		userdef.synchronize

		log @webview.mainFrameURL
	end

	# OutlineView
	#    * outlineView:child:ofItem:
	#    * outlineView:isItemExpandable:
	#    * outlineView:numberOfChildrenOfItem:
	#    * outlineView:objectValueForTableColumn:byItem:
	#    * outlineView:setObjectValue:forTableColumn:byItem:

	def outlineView_child_ofItem(ov, index, item)
		(item || @topics)[:children][index]
	end

	def outlineView_isItemExpandable(ov, item)
		(item || @topics)[:children].length.nonzero?
	end

	def outlineView_numberOfChildrenOfItem(ov, item)
		(item || @topics)[:children].length
	end

	def outlineView_objectValueForTableColumn_byItem(ov, column, item)
		item[:name]
	end

	def treeclicked(sender)
		path = sender.itemAtRow(sender.selectedRow)[:local]
		log "Tree Clicked: #{path}"
		browse path unless path.empty?
	end


	# Tableview
	def numberOfRowsInTableView(table)
		@now.length
	end

	def tableView_objectValueForTableColumn_row(table, column, row)
		@now[row][0]
	end

	def tableView_setObjectValue_forTableColumn_row(table, value, column, row)
	end

	def tableView_willDisplayCell_forTableColumn_row(table, cell, column, row)
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

	# TabView
	def tabView_willSelectTabViewItem(sender, item)
		log item.label
		if item.label == "Tree"
			# http://subtech.g.hatena.ne.jp/cho45/20071025#c1193355031
			#  > OutlineView は DataSource に、ノードの値が変わらない限り、
			#  > 同じ NSString を返すように期待してるようです。
			# NSDictionary で保持するように
			@topics = NSDictionary.dictionaryWithDictionary(@chm.topics)
			@tree.setDataSource(self)
		end
	end

	# general

	def controlTextDidChange(anot)
		filtering @search.stringValue
		@list.selectRowIndexes_byExtendingSelection(NSIndexSet.alloc.initWithIndex(0), false)
	end

	def controlTextDidEndEditing(anot)
		log "end #{@now.first.inspect}"
	end

	def jumpToCurrent(sender)
		clicked(sender)
	end

	def fast_filter(keyword)
		keyword = keyword.to_s

		if /[A-Z]/ === keyword
			r = /^#{Regexp.escape(keyword)}/
		else
			r = /^#{Regexp.escape(keyword)}/i
		end

		key = keyword[0,KEY_LENGTH].downcase

		@index
		if keyword.length.zero?
			@index
		else
			if keyword.length < KEY_LENGTH
				result = @hash.keys.select {|k| k[0, key.length] == key }.map {|k| @hash[k] }.inject([]) {|r,i| r << i}
			else
				result = @hash[key].to_a
			end

			result.select{|k,v| r === k}.sort_by{|k,v| k.length}
		end
	end

	def filtering(str)
		@now = fast_filter(str)

		@search_thread.kill rescue nil
		if @now.length.zero?
			@now << ["Loading...", [""]]
			@search_thread = Thread.start(str) do |str|
				r = /(#{str.split(//).map {|c| Regexp.escape(c) }.join(").*?(")})/i
				@now = @index.sort_by {|k,v|
					# 文字が前のほうに集っているほど高ランクになるように
					m = r.match(k)
					!m ? Float::MAX : (0...m.size).map {|i| m.begin(i) }.inject {|p,i| p + i }
				}.first(30)
				@list.reloadData
			end

			@list.usesAlternatingRowBackgroundColors = false
			@list.backgroundColor = NSColor.objc_send(
				:colorWithCalibratedRed, 0.95,
				:green, 0.90,
				:blue, 0.90,
				:alpha, 1
			)
		else
			@list.usesAlternatingRowBackgroundColors = true
		end

		@list.reloadData
	end

	def clicked(sender)
		log [:clicked, @now[@list.selectedRow].inspect]
		if @now[@list.selectedRow]
			browse @now[@list.selectedRow][1].first
		end
	end

	def browse(path)
		path = path.to_s
		return unless path
		case path
		when /^http:/
			$registered = NSURLProtocol.unregisterClass CHMInternalURLProtocol if $registered
			log "#{$registered}"
			r = NSURLRequest.requestWithURL NSURL.URLWithString(path)
			log path
			@webview.mainFrame.loadRequest r
		else
			$registered = NSURLProtocol.registerClass CHMInternalURLProtocol unless $registered
			log "#{$registered}"
			path = "/#{path}" unless path[0] == ?/
			h = @webview.stringByEvaluatingJavaScriptFromString("location.pathname+location.hash")
			unless path == h
				log [:browse, path]
				r = NSURLRequest.requestWithURL CHMInternalURLProtocol.url_for(@chm, path)
				log r
				@webview.mainFrame.loadRequest r
			end
		end
	end

	def completion(sender)
		return if @search.stringValue.empty?
		return if @now.empty?
		common = ""
		keys = @now.map{|k,v| k.split(//)}
		if @search.stringValue.to_s =~ /[A-Z]/
			keys[0].zip(*keys[1..-1]) do |a|
			m = a.first
			if a.all? {|v| m == v}
				common << m
			else
				break
			end
			end
		else
			keys[0].zip(*keys[1..-1]) do |a|
				m = a.first.downcase
				if a.all? {|v| v && (m == v.downcase)}
					common << m
				else
					break
				end
			end
		end
		if common.length > @search.stringValue.length
			@search.stringValue = common
		end
	end

	# from menu
	def searchActivate(sender)
		log "activate"
		if @search.window
			@search.window.makeFirstResponder(@search)
		end
	end

	def nextCandidate(sender)
		if @list.selectedRow <= @now.size
			@list.selectRowIndexes_byExtendingSelection(NSIndexSet.alloc.initWithIndex(@list.selectedRow+1), false)
			@list.scrollRowToVisible(@list.selectedRow)
			clicked(nil)
		end
	end

	def prevCandidate(sender)
		if @list.selectedRow > 0
			@list.selectRowIndexes_byExtendingSelection(NSIndexSet.alloc.initWithIndex(@list.selectedRow-1), false)
			@list.scrollRowToVisible(@list.selectedRow)
			clicked(nil)
		end
	end

	def jumpToHome(sender)
		browse @chm.home
	end

	def performFindPanelAction(sender)
		log "performFindPanelAction"
		# @webview.performFindPanelAction(sender) # なぜかうごかない
		text = @search.stringValue
		@webview.objc_send(
			:searchFor, text,
			:direction, true,
			:caseSensitive, false,
			:wrap, false
		)
	end

	# from MySearchWindow

	def process_keybinds(e)
		if NSInputManager.currentInputManager
			return false unless NSInputManager.currentInputManager.markedRange.empty?
		end
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
			"S- " => Proc.new {|s|
				@webview.stringByEvaluatingJavaScriptFromString <<-JS
					window.scrollBy(0, -200);
				JS
			},
			"C-\r" => Proc.new {|s|
				@now = (@chm.search(@search.stringValue) || []).map {|title,url|
					[title, [url]]
				}
				@list.reloadData
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
		eval(ChemrConfig.instance.keybinds, binding)
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
	#	def webView_decidePolicyForNavigationAction_request_frame_decisionListener(
	#		sender,
	#		actionInformation,
	#		request,
	#		frame,
	#		listener
	#	)
	#
	#		if CHMInternalURLProtocol.canHandleURL(request.URL)
	#			listener.use
	#		else
	#			NSWorkspace.sharedWorkspace.openURL(request.URL)
	#			listener.ignore
	#		end
	#	end
	#
	#	def webView_decidePolicyForNewWindowAction_request_newFrameName_decisionListener(
	#		sender,
	#		actionInformation,
	#		request,
	#		frameName,
	#		listener
	#	)
	#		if CHMInternalURLProtocol.canHandleURL(request.URL)
	#			listener.use
	#		else
	#			NSWorkspace.sharedWorkspace.openURL(request.URL)
	#			listener.ignore
	#		end
	#	end

	# webview loading delegate
	def webView_resource_didFinishLoadingFromDataSource(sender, id, datasource)
		#		log "loaded"
	end

	# debug
	def needsPanelToBecomeKey
		true
	end
end

class CHMDocument < NSDocument
	attr_reader :chm

	#- (void)makeWindowControllers
	def makeWindowControllers
		c = CHMWindowController.alloc.initWithWindowNibName("CHMDocument")
		self.addWindowController(c)
	end

	#- (BOOL)readFromURL:(NSURL *)inAbsoluteURL ofType:(NSString *)inTypeName error:(NSError **)outError
	def readFromURL_ofType_error(url, type, error)
		log "readFromURL_ofType_error #{url.path.to_s}"
		path = Pathname.new(url.path.to_s)
		if path.directory?
			@chm = CHMBundle.new(path)
		else
			@chm = Chmlib::Chm.new(path.to_s)
		end
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


