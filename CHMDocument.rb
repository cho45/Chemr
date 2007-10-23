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

#class MySearchField < NSSearchField
#
#	attr_accessor :list
#
#	ib_action :keyDown do |e|
#		log "keyDown #{e.keyCode} #{e.characters}"
#	end
#
#	ib_action :moveDown do |sender|
#		log "moveDown"
#	end
#
#	ib_action :mouseDown do |sender|
#		log "mouseDown"
#	end
#
#	ib_action :moveUp do |sender|
#		log "moveUp"
#	end
#
#	def performKeyEquivalent(e)
#		log "performKeyEquivalent"
#		false
#	end
#end


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
		browse @now.first[1].first
	end

	def filtering(str)
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
			r = NSURLRequest.requestWithURL CHMInternalURLProtocol.url_for(@chm, path)
			@webview.mainFrame.loadRequest r
		end
	end

	def searchActivate(sender)
		log "activate"
		@search.window.makeFirstResponder(@search)
	end
end
