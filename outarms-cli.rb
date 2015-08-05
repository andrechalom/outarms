#!/usr/bin/env ruby
require './outarms-core.rb' 

class NilClass
	def chomp; ""; end
end

def to_class(name)
	name.chomp.capitalize
	Object.const_get(name)
end

def to_hash(string)
	hash = {}
	string.split(",").each do |x|
		k,v = x.split(':')
		hash[k.strip().to_sym]= v.to_i
	end
	hash
end

$world = GameWorld.new

puts "\n\nWelcome to the Command Line Interface for Outarms"
puts "Setting up the map...\n\n"
puts "To add an object, type the name of the object. Then you will be prompted for stats"
loop do
	puts "Add new object? "; obj = gets.chomp
    break if obj==""
	className = to_class(obj)
	puts "Options (option: value, comma separated)?"; opt = gets.chomp
	className.new (to_hash(opt))
end

# GAME LOOP
tick = 0
while Core.alive == true
	tick +=1
#	$world.report
	$world.update
	# STRATEGY
	Tower.each{ |t| 
		if $world.coins > t.upcost
			t.upgrade
			$world.add_coins(-t.upcost)
		end
	}
end

puts "Game over on tick #{tick} (#{format(tick/60)})"
$world.report
