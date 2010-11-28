module Mongoid
	module Acts
		module Tree
			
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
					acts_as_tree_options[:order] or []
				end
			end
			
		end
	end
end
