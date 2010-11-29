module Mongoid
	module Acts
		module Tree


			class Children < Mongoid::Criteria
				
				def initialize(owner, tree_base_class)
					@parent = owner
					@tree_base_class = tree_base_class
					super(tree_base_class)
					self.criteria.merge tree_base_class.where(@parent.parent_id_field => @parent.id).order_by(@parent.tree_order)
				end
				
				alias_method :size, :count
				
				def build(attributes)
					child = @parent.class.new(attributes)
					child = self.set_parent_path_and_depth_information(child)
					child
				end
				
				def create(attributes)
					child = self.build(attributes)
					child.save
					child
				end
				
				def <<(object)
					object = self.set_parent_path_and_depth_information(object)
					object.save
				end
				
				#Clear children list
				def clear!
					self.each(&:destroy)
				end
				
				
				
			protected
			
			
				def set_parent_path_and_depth_information(child)
					if self.already_exists_in_tree?(child)
						child.instance_variable_set :@_cyclic, true
					else
						# TODO: This seems pretty redundant with :set_position_information in acts_as_tree.rb
						child.write_attribute child.parent_id_field, @parent._id
						child[child.path_field] = @parent[@parent.path_field] + [@parent._id]
						child[child.depth_field] = @parent[@parent.depth_field] + 1
						child.instance_variable_set :@_will_move, true
					end
					child
				end
				
				def already_exists_in_tree?(child)
					root = @parent.root
					tree_ids = root.class.collection.find({ @parent.path_field => root.id }, { :fields => { "_id" => 1 } }).collect(&:id) + [ root.id ]
					tree_ids.include?(child.id)
				end
				
			end # Children

			
		end # Tree
	end # Acts
end # Mongoid
