#!/usr/bin/env ruby


require "pathname"
require "singleton"

class ChemrConfig
	include Singleton

	PATH = Pathname.new("#{ENV["HOME"]}/.chemr")

	@@instance = nil


	def initialize
	end

	def userstyle
		(PATH + "userstyle.css").to_s
	end

	def keybinds
		(PATH + "keybinds.rb").read
	rescue Errno::ENOENT
		""
	end

	def initrc
		(PATH + "initrc.rb").read
	rescue Errno::ENOENT
		""
	end
end

