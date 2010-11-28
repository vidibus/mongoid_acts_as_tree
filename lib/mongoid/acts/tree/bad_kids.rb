module Mongoid
	module Acts
		module Tree

			class Children < Mongoid::Criteria
				#TODO: improve accessors to options to eliminate object[object.parent_id_field]

				def initialize(owner, tree_base_class)
					@parent = owner
					@tree_base_class = tree_base_class
					#self.concat find_children_for_owner.to_a
					self.find_children_for_owner
				end

				#Add new child to list of object children
				def <<(object, will_save=true)
=begin				
					if object.descendants.include? @parent
						object.instance_variable_set :@_cyclic, true
					else
						object.write_attribute object.parent_id_field, @parent._id
						object[object.path_field] = @parent[@parent.path_field] + [@parent._id]
						object[object.depth_field] = @parent[@parent.depth_field] + 1
						object.instance_variable_set :@_will_move, true
						object.save if will_save
					end

					super(object)
=end					

					object.write_attribute object.parent_id_field, @parent._id
					object[object.path_field] = @parent[@parent.path_field] + [@parent._id]
					object[object.depth_field] = @parent[@parent.depth_field] + 1
					#object.instance_variable_set :@_will_move, true
					object.save if will_save
				end

				def build(attributes)
					child = @tree_base_class.new(attributes)
					#self.push child
					child
				end

				alias create build

				alias push <<

				#Deletes object only from children list.
				#To delete object use <tt>object.destroy</tt>.
				def delete(object_or_id)
					object = case object_or_id
						when String, BSON::ObjectId
							@tree_base_class.find object_or_id
						else
							object_or_id
					end

					object.write_attribute object.parent_id_field, nil
					object[object.path_field]      = []
					object[object.depth_field]     = 0
					object.save

					super(object)
				end

				#Clear children list
				def clear
					self.each do | child |
						@parent.children.delete child
					end
				end

			private

				def find_children_for_owner
					@tree_base_class.where(@parent.parent_id_field => @parent.id).order_by @parent.tree_order
				end

			end

		end
	end
end
