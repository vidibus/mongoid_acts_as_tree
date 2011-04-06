require "mongoid"
require "mongoid/acts/tree/fields"
require "mongoid/acts/tree/children"

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
						:depth_field     => "depth",
						:class           => self
					}.merge(options)

					class_attribute :acts_as_tree_options
					self.acts_as_tree_options = options

					include InstanceMethods
					include Fields
					extend Fields
					extend ClassMethods

					field parent_id_field, :type => BSON::ObjectId
					field path_field, :type => Array,  :default => []
					field depth_field, :type => Integer, :default => 0
					
					index parent_id_field
					index path_field

					self.class_eval do
						define_method "#{parent_id_field}=" do | new_parent_id |
						  if new_parent_id.present?
								self.write_attribute parent_id_field, new_parent_id
							else
								self.write_attribute parent_id_field, nil
								self[path_field] = []
								self[depth_field] = 0
						  end
						end
					end
					
					before_validation :set_position_information, :if => lambda { |obj|
						# TODO: Not a fan of this, but mongoid does not seem to be correctly honoring :on => :create/:update
						(obj.new_record? && obj[self.parent_id_field].present?) or (!obj.new_record? && obj["#{self.parent_id_field}_changed?".to_sym])
					}
					#before_validation	:set_position_information#, :on => :create, :unless => lambda { |obj| obj[self.parent_id_field].blank? }
					#before_validation	:set_position_information, :on => :update, :if => lambda { |obj| obj["#{self.parent_id_field}_changed?".to_sym] }
					
					validate					:will_save_tree
					after_save				:move_children
					after_destroy			:destroy_descendants
				end
			end

			module ClassMethods
				def roots
					self.where(parent_id_field => nil).order_by tree_order
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
					return true if other.kind_of?(acts_as_tree_options[:class]) and other._id == self._id
					false
				end

				def will_save_tree
					if @_cyclic
						errors.add(:base, "Can't be children of a descendant")
					end
				end

				def parent
					@_parent or (self[parent_id_field].nil? ? nil : acts_as_tree_options[:class].find(self[parent_id_field]))
				end
				
				def parent=(new_parent)
					self.send("#{parent_id_field}=".to_sym, new_parent.id)
				end

				def root?
					self[parent_id_field].nil?
				end
				
				def root_id
					self[path_field].first
				end

				def root
					self[path_field].first.nil? ? self : acts_as_tree_options[:class].find(self[path_field].first)
				end

				def ancestors
					return [] if root?
					acts_as_tree_options[:class].where(:_id.in => self[path_field]).order_by(depth_field)
				end

				def self_and_ancestors
					ancestors << self
				end

				def siblings
					acts_as_tree_options[:class].where(:_id.ne => self._id, parent_id_field => self[parent_id_field]).order_by tree_order
				end

				def self_and_siblings
					acts_as_tree_options[:class].where(parent_id_field => self[parent_id_field]).order_by tree_order
				end

				def children
					Children.new self, acts_as_tree_options[:class]
				end

				def children=(new_children_list)
					self.children.replace_with(new_children_list)
				end

				alias replace children=

				def descendants
					return [] if new_record?
					self.class.all_in(path_field => [self._id]).order_by tree_order
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
					if @_will_move
						@_will_move = false
						self.children.each do | child |
							child.set_position_information
							child.save
						end
						@_will_move = true
					end
				end

				def destroy_descendants
					self.descendants.each(&:destroy)
				end
				
				def set_position_information
					if parent.present? && parent.already_exists_in_tree?(self)
						self.instance_variable_set :@_cyclic, true
					else
						self.update_position_information
					end
				end
				
				def update_position_information
					@_will_move = true
					parent.nil? ? self.clear_parent_information : self.set_parent_information
				end
				
				def clear_parent_information
					self.write_attribute parent_id_field, nil
					self[path_field] = []
					self[depth_field] = 0
				end
				
				def clear_parent_information!
					self.clear_parent_information
					self.save
				end
				
				def set_parent_information(parent=self.parent)
					self.write_attribute parent_id_field, parent._id
					self[path_field] = parent[path_field] + [parent._id]
					self[depth_field] = parent[depth_field] + 1
				end
				
				
				def already_exists_in_tree?(root)
					tree_ids = root.class.collection.find({ root.path_field => root.id }, { :fields => { "_id" => 1 } }).collect(&:id) + [ root.id ]
					tree_ids.include?(self.id)
				end
			end

		end
	end
end

