require 'acts_as_mysqlsearchable'
ActiveRecord::Base.send(:include, ActiveRecord::Acts::Mysqlsearchable)

