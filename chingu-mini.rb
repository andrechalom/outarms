require 'gosu'
require 'forwardable'
# Copies functionality from the Chingu library, but in a way that the GameObjects may or may not be associated with
# a graphical user interface
# FUNDAMENTAL CHANGES: you MUST have an active gamestate. You cannot register objects directly on the window
module ChinguMini
	class Window < Gosu::Window
		attr_reader :game_state_manager, :height, :width
		attr_accessor :cursor
		extend Forwardable
		def_delegator :game_state_manager, :push_game_state
		def_delegator :game_state_manager, :pop_game_state
		def initialize(width = 800, height = 600, fullscreen = false, update_interval = 16.666666)
			raise "Cannot create a new #{self.class} before the old one has been closed" if $window
			fullscreen ||= ARGV.include?("--fullscreen")
			$window = super(width, height, fullscreen, update_interval)
			@game_state_manager = GameStateManager.new
			@cursor = true
			@mouse_is_down = false
			@mouse_was_down = false
		end
	    def needs_cursor?
			@cursor
		end
		def current_scope
			@game_state_manager.current_game_state 
		end
		def update
			# Dispatch inputmap for main window
			# dispatch_input_for(self)
			# Dispatch input for all input-clients handled by to main window (game objects with input created in main win)
			# @input_clients.each { |game_object| dispatch_input_for(game_object) unless game_object.paused? }
			# Call update() on all game objects belonging to the current game state.
			@game_state_manager.update
			@mouse_was_down = @mouse_is_down
			@mouse_is_down = button_down?(Gosu::MsLeft)
		end
		def mouse_up?
			@mouse_was_down && ! @mouse_is_down
		end
		def draw; @game_state_manager.draw; end
	end
	class GameStateManager
		def initialize
			@inside_state = nil
			@game_states = []
		end
		def current_game_state; @inside_state || @game_states.last; end
		alias :current current_game_state
		def game_states; @game_states.reverse; end
		def update;	current.update; end
		def draw; current.draw; end
		def push_game_state(state, options = {})
			options = {:setup => true, :finalize => true}.merge(options)
			new_state = game_state_instance(state)
			@inside_state = new_state
			# Make sure the game state knows about the manager
			new_state.game_state_manager = self
			# Call setup
			new_state.setup if new_state.respond_to?(:setup) && options[:setup]
			# Give the soon-to-be-disabled state a chance to clean up by calling finalize() on it.
			current_game_state.finalize if current_game_state.respond_to?(:finalize) && options[:finalize]
			@game_states.push(new_state)
			@inside_state = nil
		end
		alias :push :push_game_state
		def pop_game_state(options = {})
			options = {:setup => true, :finalize => true}.merge(options)
			# Give the soon-to-be-disabled state a chance to clean up by calling finalize() on it.
			current_game_state.finalize if current_game_state.respond_to?(:finalize) && options[:finalize]
			# Activate the game state "below" current one with a simple Array.pop
			@game_states.pop
			# Call setup on the new current state
			# current_game_state.setup if current_game_state.respond_to?(:setup) && options[:setup]
		end
	    alias :pop :pop_game_state
		def game_state_instance(state)
			state = state.new if state.is_a? Class
			return state # if new_state.kind_of? Chingu::GameState # useless check.
		end
	end
	class GameState
		attr_accessor :game_state_manager
	    def initialize(options = {})
			@options = options
			@game_objects = []
		end
		def setup; end #placeholder
		def finalize; end #placeholder
		def update; @game_objects.each{ |x| x.update}; end
		def draw; @game_objects.each{ |x| x.draw}; end
		def register(obj); @game_objects.push(obj) unless @game_objects.include?(obj); end
		def unregister(obj); @game_objects.delete(obj) if @game_objects.include?(obj); end
	end
	module HazImage
		attr_accessor :x, :y, :z
		def setup_image(options = {})
			@options = options
			image = options[:image] 
			image = "media/#{self.class}.png" if image.nil? and File.exists?("media/#{self.class}.png")

			@image = Gosu::Image.new($window, image, false) unless image.nil?
			@x = options[:x] || 0
			@y = options[:y] || 0
			@z = options[:z] || 0
			@mouseover = options[:mouseover] || false
			@color = options[:color] || 0xFFFFFFFF
			@factor = options[:factor] || 1
			@action = options[:action] || nil
		end
		def width; @image.width; end
		def height; @image.height; end
		def draw
			@image.draw(@x, @y, @z, @factor, @factor, @color) unless @image.nil?
		end
		def register
			$window.current_scope.register(self)
			self
		end
		def unregister
			$window.current_scope.unregister(self)
		end
		def mouseover
			(@x < $window.mouse_x && $window.mouse_x < @x + @image.width) && (@y < $window.mouse_y && $window.mouse_y < @y + @image.height)
		end
		def mouse_on
				@color = @options[:emph] || 0xFFFF0000 # can change the behaviour here
		end
		def mouse_off
				@color = @options[:color] || 0xFFFFFFFF
		end
		def update
			if @mouseover && mouseover
				mouse_on
			else 
				mouse_off
			end
			if @mouseover && mouseover && $window.mouse_up? 
				if @action.is_a? Class
					$window.push_game_state(@action)
				end
				if @action.is_a? Symbol
					if respond_to?(@action)
						self.send @action
					else
						$window.current_scope.send @action
					end
				end
				if @action.is_a? Proc
					@action.call
				end
			end
		end
	end
	class BasicGameObject
		include HazImage
		def initialize(options={})
			setup_image(options)
		end
	end
	class Text < BasicGameObject
		attr_reader :text, :size, :gosu_font, :line_spacing, :align, :max_width, :image
		@@color = 0xFFFFFFFF
		@@zorder = 0
		@@size = 20
		@@font = Gosu::default_font_name
		@@padding = 5
		@@max_width = nil
		@@align = :left
		def self.font; @@font; end
		def self.font=(value); @@font = value; end
		def self.size; @@size; end
		def self.size=(value); @@size = value; end
		def self.padding; @@padding; end
		def self.padding=(value); @@padding = value; end
		def self.zorder; @@zorder; end
		def self.zorder=(value); @@zorder = value; end
		def self.color; @@color; end
		def self.color=(value); @@color = value; end
		def self.max_width; @@max_width; end
		def self.max_width=(value); @@max_width = value; end
		def self.align; @@align; end
		def self.align=(value); @@align = value; end
		def initialize(text, options = {})   
			if text.is_a? Hash
				options = text
				text = nil
			end
			@zorder = options[:zorder] || @@zorder
			@color = options[:color] || @@color
			@size = options.delete(:size) || @@size
			super(options.merge({color: @color}))
			@text = text || options[:text] || ""
			@font = options[:font] || @@font || Gosu::default_font_name()
			@line_spacing = options[:line_spacing] || 1
			@align = options[:align] || @@align
			@max_width = options[:max_width] || @@max_width
			@padding = options[:padding] || @@padding

			@gosu_font = Gosu::Font.new($window, @font, @size)
			create_image
		end
		def text=(text)
			return if text.dup == @text # Have to make a dup for content comparison
			@text = text.dup # Make a copy, again to have a different Objectid
			create_image
		end

		private
		# Create the actual image from text and parameters supplied.
		def create_image
			if @max_width
				@image = Gosu::Image.from_text($window, @text, @font, @size, @line_spacing, @max_width, @align)
			else
				@image = Gosu::Image.from_text($window, @text, @font, @size)
			end
		end
	end
end
