
require "yaml"

class CHMBundle
	attr_reader :path

	def initialize(path)
		@path   = path
		@bundle = NSBundle.bundleWithPath(path.realpath.to_s)
		@info   = @bundle.infoDictionary
		@home   = @info[:CHMHome].to_s
		@title  = @info[:CHMTitle].to_s
		if @info[:CHMKeyword]
			if @info[:CHMKeyword].to_s.match(/\.dat$/)
				@index = retrieve_object(@info[:CHMKeyword]).split(/\n/).map {|i|
					name, uri = *i.split(/\t/, 2)
					[name, [uri]]
				}
			else
				@index = YAML.load(retrieve_object(@info[:CHMKeyword]))
			end
		end
		if @info[:CHMTOC]
			@topics = YAML.load(retrieve_object(@info[:CHMTOC]))
		end
	rescue => e
		OSX.NSRunAlertPanel("Error", e.inspect, "OK", "", nil)
	end

	def index
		@index
	end

	def home
		@home
	end

	def title
		@title
	end

	def topics
		@topics
	end

	def searchable?
		false
	end

	def search(text)
		nil
	end

	def retrieve_object(path)
		log path
#		p bundle
#		p bundle.resourcePath
#		p bundle.infoDictionary

		log [@bundle.resourcePath, path].inspect
		begin
			File.read(@bundle.resourcePath + path)
		rescue Errno::ENOENT => e
			log e.inspect
			raise Chmlib::Chm::RetrieveError
		end
	end
end

