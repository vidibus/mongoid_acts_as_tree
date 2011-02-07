module Mongoid
	module Acts
		module Tree


			class Children < Mongoid::Criteria
				
				def initialize(owner, tree_base_class)
					@parent = owner
					@tree_base_class = tree_base_class
					super(tree_base_class)
					# TODO: Don't really like this, but Criteria#fuse doesn't seem to work as expected?
					self.selector.merge!(@parent.parent_id_field => @parent.id)
					self.options.merge!(:sort => @parent.tree_order)
				end
				
				alias_method :size, :count
				
				def build(attributes)
					child = @parent.class.new(attributes)
					child.parent = @parent
					child
				end
				
				def create(attributes)
					child = self.build(attributes)
					child.save
					child
				end
				
				def <<(object)
					object.parent = @parent
					object.save
				end
				alias push <<
				
				#Clear children list
				def clear!
					self.each(&:destroy)
				end
				
			end # Children

			
		end # Tree
	end # Acts
end # Mongoid
