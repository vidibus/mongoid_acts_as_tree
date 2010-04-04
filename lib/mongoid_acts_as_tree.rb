require "mongoid"

module Mongoid
  module Acts
    module Tree
      def self.included(model)
        model.class_eval do
          extend InitializerMethods
        end
      end

      module InitializerMethods
        def acts_as_tree(options = {})
          options = {
            :parent_id_field => "parent_id",
            :path_field      => "path",
            :depth_field     => "depth"
          }.merge(options)

          write_inheritable_attribute :acts_as_tree_options, options
          class_inheritable_reader :acts_as_tree_options

          include InstanceMethods
          include Fields
          extend Fields
          extend ClassMethods

          field parent_id_field, :type => Mongo::ObjectID
          field path_field, :type => Array,  :default => [], :index => true
          field depth_field, :type => Integer, :default => 0

          after_save      :move_children
          validate        :will_save_tree
          before_destroy  :destroy_descendants
        end
      end

      module ClassMethods
        def roots
        	self.where(:parent_id => nil).order_by tree_order
        end
      end

      module InstanceMethods
      	def [](field_name)
      		self.send field_name
      	end

      	def []=(field_name, value)
      		self.send "#{field_name}=", value
      	end

        def ==(other)
          return true if other.equal?(self)
          return true if other.instance_of?(self.class) and other._id == self._id
          false
        end

#        def parent=(var)
#          var = self.class.find(var) if var.is_a? String

#          if self.descendants.include? var
#            @_cyclic = true
#          else
#            @_parent = var
#            fix_position
#            @_will_move = true
#          end
#        end

        def will_save_tree
          if @_cyclic
            errors.add(:base, "Can't be children of a descendant")
          end
        end

        def fix_position
          if parent.nil?
            self[parent_id_field] = nil
            self[path_field] = []
            self[depth_field] = 0
          else
            self[parent_id_field] = parent._id
            self[path_field] = parent[path_field] + [parent._id]
            self[depth_field] = parent[depth_field] + 1
            self.save
          end
        end

        def parent
          @_parent or (self[parent_id_field].nil? ? nil : self.class.find(self[parent_id_field]))
        end

        def root?
          self[parent_id_field].nil?
        end

        def root
          self[path_field].first.nil? ? self : self.class.find(self[path_field].first)
        end

        def ancestors
          return [] if root?
          self.class.find(self[path_field])
        end

        def self_and_ancestors
          ancestors << self
        end

        def siblings
          self.class.all(:conditions => {:_id => {"$ne" => self._id}, parent_id_field => self[parent_id_field]})#, :order => tree_order)
        end

        def self_and_siblings
          self.class.all(:conditions => {parent_id_field => self[parent_id_field]})#, :order => tree_order)
        end

        def children
        	#XXX
        	Children.new self
#          self.class.all(:conditions => {parent_id_field => self._id})#, :order => tree_order})
        end

        def descendants
          return [] if new_record?
#          self.class.find(:all, :conditions => {:path.in => self._id})
#          self.class.where(path_field.to_sym.in => self._id)
          self.class.all(:conditions => {path_field => self._id})#, :order => tree_order})
        end

        def self_and_descendants
          [self] + self.descendants
        end

        def is_ancestor_of?(other)
          other[path_field].include?(self._id)
        end

        def is_or_is_ancestor_of?(other)
          (other == self) or is_ancestor_of?(other)
        end

        def is_descendant_of?(other)
          self[path_field].include?(other._id)
        end

        def is_or_is_descendant_of?(other)
          (other == self) or is_descendant_of?(other)
        end

        def is_sibling_of?(other)
          (other != self) and (other[parent_id_field] == self[parent_id_field])
        end

        def is_or_is_sibling_of?(other)
          (other == self) or is_sibling_of?(other)
        end

        def move_children
#        	puts "move_children for #{self.name}" if $verbose

          if @_will_move
            @_will_move = false
            for child in self.children
#            	puts "fixing position for #{child.name}" if $verbose
              child.fix_position
              child.save
            end
            @_will_move = true
          end
        end

        def destroy_descendants
          self.descendants.each &:destroy
        end
      end






			class Children < Array

				def initialize(owner)
					@owner = owner
					self.concat find_children_for_owner.to_a
				end

				def find_children_for_owner
					@owner.class.find(:all, :conditions => {@owner.parent_id_field => @owner.id})
				end

				def <<(object)
					if object.descendants.include? @owner
						object.instance_variable_set :@_cyclic, true
					else
	          object[object.parent_id_field] = @owner._id
	          object[object.path_field] = @owner[@owner.path_field] + [@owner._id]
	          object[object.depth_field] = @owner[@owner.depth_field] + 1
						object.instance_variable_set :@_will_move, true
	          object.save
					end

					super(object)
				end

				def delete(object_or_id)
					object = case object_or_id
						when String
							@owner.class.where(:id => object_or_id)
						else
							object_or_id
					end

					object._parent_id = nil
					object._parent_ids = (object._parent_ids || []) - [@owner.id]
					object.save
					super(object)
				end

			end













      module Fields
        def parent_id_field
          acts_as_tree_options[:parent_id_field]
        end

        def path_field
          acts_as_tree_options[:path_field]
        end

        def depth_field
          acts_as_tree_options[:depth_field]
        end

        def tree_order
          acts_as_tree_options[:order] or ""
        end
      end
    end
  end
end

