#!/usr/local/bin/ruby

require '../lib/sunriseset.rb'
require 'date'
#require 'sunriseset'

puts SunRiseSet.new(DateTime.now  , 53.5, 138.9)
puts '####'
#puts SunRiseSet.new(DateTime.now  , 53.4564,138.8954)
today = SunRiseSet.new(DateTime.now,-36.991,174.487)
puts today