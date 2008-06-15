module ActiveRecord
  module Acts
    module Mysqlsearchable
      
      def self.included(base)
        base.extend(ClassMethods)
      end
      
      module ClassMethods
        def acts_as_mysqlsearchable(options = {})
          
          # Boolean mode enables special searchparams like +, - and ~ 
          # It's good stuff, so let's do it by default.
          #
          # :score_column defaults to "score" but it's you can change it if you allready have a column named "score"
          #
          # :sql_calc_found_rows Does blow away SQL limit-optimization, but since you usually want to sort
          # with score that optimization is lost anyhow.
          #
          default_options = {
            :score_column => "score",
            :sql_calc_found_rows => true,
            :in_boolean_mode => true,
            :with_query_expansion => false
          }
          default_options.update(options)

          class_inheritable_accessor :acts_as_mysqlsearchable_options

          include ActiveRecord::Acts::Mysqlsearchable::InstanceMethods
          extend ActiveRecord::Acts::Mysqlsearchable::SingletonMethods
          
          self.acts_as_mysqlsearchable_options = default_options
        end
      end
      
      module SingletonMethods

        # MYSQL STOPWORDS: http://dev.mysql.com/doc/refman/5.0/en/fulltext-stopwords.html
        def find_by_contents(query, options = {})
          
          fields = acts_as_mysqlsearchable_options[:fields].join(",")
            
          # MORE INFO - http://dev.mysql.com/doc/refman/5.0/en/fulltext-query-expansion.html
          expansion = acts_as_mysqlsearchable_options[:with_query_expansion] ? "WITH QUERY EXPANSION" : ""

          # MORE INFO - http://dev.mysql.com/doc/refman/5.0/en/fulltext-boolean.html
          mode = acts_as_mysqlsearchable_options[:in_boolean_mode] ? "IN BOOLEAN MODE" : ""

          calc = acts_as_mysqlsearchable_options[:sql_calc_found_rows] ? "SQL_CALC_FOUND_ROWS" : ""
          
          # IN BOOLEAN MODE doesn't seem to mix well with WITH QUERY EXPANSION
          expansion = "" if acts_as_mysqlsearchable_options[:in_boolean_mode]
          
          # Stop SQL-injections. This can be solved in :condition in a nicer way, but not in :select. So we do it ourselves instead.
          unless query.nil?
            query.gsub!(/\\/, "")
            query.gsub!(/\'/, "\\'")
            query.gsub!(/\"/, "\\\"")
            
            query.gsub!(/\\/, "")
            query.gsub!(/'/, "")
            #query.gsub!(/"/, "")
          end

          # Needs rails edge / 1.2+ to support scoping of :order.
          default_scope = {
            :select => "#{calc} *, MATCH (#{fields}) AGAINST ('#{query}') AS #{acts_as_mysqlsearchable_options[:score_column]}",
            :conditions => "MATCH (#{fields}) AGAINST ('#{query}' #{mode} #{expansion})",
            :order => "#{acts_as_mysqlsearchable_options[:score_column]} DESC",
          }
          
          with_scope(:find => options) do
            with_scope(:find => default_scope) do
              if block_given?
                yield
              else
                find(:all)
              end
            end
          end
        end
      end
      
      # Nothing I can think of yet, ideas?
      module InstanceMethods
      end

    end
  end
end
