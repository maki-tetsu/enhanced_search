require File.join(File.dirname(__FILE__), 'lib/enhanced_search')

ActiveRecord::Base.send(:include, MakiTetsu::Enhanced::Search)
