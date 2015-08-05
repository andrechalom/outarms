# Class inspired by Chingu::BasicGameObject https://github.com/ippa/chingu/blob/master/lib/chingu/basic_game_object.rb
# These classes however don't require a graphic interface
class GameObject
	# Para entender essa linha: http://openmymind.net/2010/6/25/Learning-Ruby-class-self/
	class << self; attr_accessor :instances; end

	attr_reader :x, :y, :hp, :armor, :range, :level, :speed

	def initialize(options = {})
		$world.add_game_object(self)
		@options = options
		@x = options[:x] || 0
		@y = options[:y] || 0
		@hp = options[:hp] || 0
		@armor = options[:armor] || 0
		@range = options[:range] || 30
		@level = options[:level] || 1
		@speed = options[:speed] || 0
		# Quanto o objeto jah eh criado com level alto, chame a funcao upgrade
		# para subir os stats
		ups = @level - 1
		ups.times{upgrade; @level-= 1}

		# Quando GUI está ligada, cria a imagem
		setup_image(options)
		# Adiciona essa instancia na lista das instancias de classe
		self.class.instances ||= Array.new
		self.class.instances << self
	end

	def damage(ammount)
		ammount -= @armor
		ammount = 0.1 if ammount < 0.1
		@hp -= ammount
	end

	def setup_image(options = {}); end # PLACEHOLDER for GUI
	def dist(object)
		dx = @x-object.x
		dy = @y-object.y
		Math.hypot(dx, dy)
	end

	def self.all
		instances ? instances.dup : []
	end 

	def self.each; all.each { |object| yield object }; end

	def report
		puts "I am a level #{level} #{self} on #{x}, #{y}. HP: #{hp}"
	end

	def destroy
		$world.delete_game_object(self)
		self.class.instances.delete(self)
	end

	# placeholders for methods
	def update; end 
	def upgrade
		@level += 1
	end
	def upcost; puts "Trying to upgrade a base GameObject!"; end
	def up_if_possible
		if $world.coins > upcost
			$world.add_coins(-upcost)
			upgrade
		end	
	end
end

class Timer
	class << self; attr_accessor :instances; end
	def self.all; instances ? instances.dup : []; end 
	def self.each; all.each { |object| yield object }; end

	attr_reader :interval, :current, :action
	def initialize(owner, interval, action)
		@owner = owner
		@interval = interval
		@action = action
		@current = interval
		self.class.instances ||= Array.new
		self.class.instances << self
	end
	def update
		return if @interval == 0; #not even ticking...
		@current -= 1	
		if @current == 0
			@current = @interval
			@owner.send @action
		end
	end
end

class GameWorld
	attr_reader :coins, :kills, :game_objects
	def initialize
		@game_objects = []
		@coins = 0; @kills = 0
	end
	def add_game_object(object)
		@game_objects.push(object)
	end
	def delete_game_object(object)
		@game_objects.delete(object)
	end
	def destroy_all
		@game_objects.dup.each{|x| x.destroy }
	end
	def update
		Timer.each{|x| x.update}
		@game_objects.each{|x| x.update}
	end
	def report
		puts "Kills: #{kills}, coins #{coins}\nObject list:"
		@game_objects.each{|x| x.report}
	end
	def killed; @kills +=1; end
	def add_coins(ammount); @coins += ammount; end
end

class Creep < GameObject
	attr_reader :visible
	def initialize(options = {})
		super(options)
		@visible = true
	end
	def nearest_core
		cores = Core.all
		return [cores[0], dist(cores[0])] if cores.size == 1
		n = cores[0]; d = dist(n) #UNTESTED!!
		cores.each{|x| 
			if dist(x) < d
				n = x
				d = dist(n)
			end
		}
		return [n, d]
	end
	def update
		super
		if @hp < 0 #Destroyed
			$world.killed
			$world.add_coins(@speed+3*@armor)
			destroy
		end
		core, dist = nearest_core
		if dist < speed # Reached
			core.damage(hp)
			destroy
		else # Moving
			@x += (core.x - @x)/dist*@speed
			@y += (core.y - @y)/dist*@speed
		end
	end
end

class Spawner < GameObject
	def initialize(options = {})
		super(options)
		Timer.new(self, 70, :spawn) # Creates a timer to spawn every 70 ticks
		Timer.new(self, 50*70, :upgrade) # Creates a timer to upgrade spawning every 50 spawns
	end
	def spawn
		Creep.new({x: @x+14, y: @y+23, speed: 2*@level, hp: 1*@level, level:@level})
	end
	def upgrade
		@level += 1
	end
	def update
		super
	end
end

class Tower < GameObject
	def initialize(options = {}); 
		@maxtimer = options[:timer] || 30
		@shoottimer = @maxtimer
		@damage = options[:damage] || 3
		super(options);
		# @range = options[:range] || 30 <- done on super
	end
	def upcost
		@level*@level*90
	end
	def upgrade
		@level +=1
		@range += 10
		@maxtimer /= 1.1
		@damage += 3
	end
	def update
		super
		if @shoottimer > 0
			@shoottimer -= 1
		else
			Creep.each { |creep|
				if dist(creep) < @range && creep.visible
					#FIRE!!
					@shoottimer = @maxtimer
					creep.damage(@damage)
					break;
				end
			}
		end
	end
end

class Core < GameObject
	def self.alive
		Core.each{|x| return false if x.hp < 0}
		return true
	end
end

def format(secs)
	string = ""
	hours = secs / (60*60)
	secs -= hours*60*60
	string += "#{hours} hours, " if hours > 0
	minutes = secs / 60
	secs -= minutes*60
	string += "#{minutes} minutes, " if minutes > 0 
	string += "#{secs} seconds"
	string
end

