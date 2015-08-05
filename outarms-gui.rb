#!/usr/bin/env ruby
# Toda a mecanica de jogo fica em outarms-core
require './outarms-core.rb' 
# Usa partes da biblioteca Chingu, plugaveis em um jogo CLI
require './chingu-mini.rb'
require 'texplay'
include ChinguMini

class GameWindow < Window # Classe principal da GUI
	def initialize
		# creates the game window
		super
		self.caption = "Outarms"
		# Carrega as informações de configuração (QUANDO EXISTIR)
		# Stats.load
		# Registra os inputs GLOBAIS (ou seja, para qualquer game state QUANDO FUNCIONAR
		# self.input = {:m => :mute}
		# Entra no state GameMenu
		push_game_state(GameMenu)
	end
end

class GameMenu < GameState
	# Setup method creates and *registers* game objects for automatic draw & update
	def setup
		BasicGameObject.new({image: "media/menu.jpg", z:0}).register
		# Sets the default style for texts
		Text.font = "media/alien.ttf"; Text.size = 72
		Text.max_width = 800; Text.align = :center
		# Adds text and menu
		Text.new("Outarms", {y:100, z: 1}).register
		# if :action is a Class, pushes it to the game state
		Text.new("Play", {y:340, mouseover: true, z: 1, action: GameScreen}).register
		Text.new("Configure", {y:420, mouseover: true, z: 1, action: ConfigMenu}).register
		# if :action is a :symbol, calls this method on current game state
		Text.new("Exit", {y:500, mouseover: true, z: 1, action: :exit}).register
	end
end

class ConfigMenu < GameState
	def setup
		BasicGameObject.new({image: "media/config.jpg", z:0}).register
		# Sets the default style for texts
		Text.font = "media/alien.ttf"; Text.size = 48
		Text.max_width = 800; Text.align = :center
		# Adds text and menu
		Text.new("To be implemented", {y:100, z: 1}).register
		Text.new("Back", {y:500, mouseover: true, z: 1, action: lambda{$window.pop_game_state}}).register
	end
end

# Game objects will automatically register on the GameWorld object, NOT on the game state!
class GameWorld
	def draw
		@game_objects.each{|x| x.draw}
	end
end

module HazMouseOver
	def mouse_on
		x = @x; y = @y + @image.height+5;
		unless @text.is_a? Text
			@text = Text.new("", {x: x, y: y, z:2, align: :left, size: 20}) 
			# Precisa deixar eles dentro da tela =/
		end
		@text.text="Level #{level} #{self.class}" 
		@text.register
	end
	def mouse_off
		@text.unregister unless @text.nil?
	end
end
class Spawner; include HazImage;
 include HazMouseOver
end
class Core; include HazImage; end
class Creep; include HazImage; end


class Tower 
	include HazImage
	include HazMouseOver
end



class GameScreen < GameState
	def setup
		BasicGameObject.new({image: "media/game.jpg", z:0}).register
		$world = GameWorld.new
		$world.add_coins(200)
		Core.new({hp:100, y:300})
		Spawner.new({x:750, y: 520, mouseover: true})
		Spawner.new({x:750, y: 20, mouseover: true})
		@toptext = Text.new("", {size: 28, align: :left}).register
	end
	def update
		super
		$world.update
		if $window.mouse_up?
			legal = true
			x = $window.mouse_x; y = $window.mouse_y
			Tower.each {|obj| 
				legal = false if obj.x-obj.width < x && x < obj.x + obj.width && obj.y - obj.height < y && y < obj.y + obj.height
			}
			
			# is it a legal position to place a tower??
			if legal && $world.coins > 30
				$world.add_coins(-30)
				Tower.new({x: $window.mouse_x, y: $window.mouse_y, mouseover: true, action: :up_if_possible})
			end
		end
		@toptext.text = "Kills: #{$world.kills}, coins: #{$world.coins}"
	end
	def draw
		super
		$world.draw
	end
end

GameWindow.new.show
