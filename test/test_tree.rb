require 'helper'
require 'set'

$verbose = false

class TestMongoidActsAsTree < Test::Unit::TestCase
	
	context "Tree" do
		setup do
			@root_1				= Category.create(:name => "Root 1")
			@child_1			= Category.create(:name => "Child 1")
			@child_2			= Category.create(:name => "Child 2")
			@child_2_1		= SubCategory.create(:name => "Child 2.1")
			@child_2_1_1 	= SubCategory2.create(:name => "Sub Child 2.1.1")
			@child_3			= SubCategory.create(:name => "Child 3")
			
			@root_2				= Category.create(:name => "Root 2")
			
			@root_1.children << @child_1
			@root_1.children << @child_2
			@root_1.children << @child_3

			@child_2.children << @child_2_1
			@child_2_1.children << @child_2_1_1
		end
		
		should "have 3 Children for @root_1" do
			assert_equal 3, @root_1.children.count
		end
		
		should "have 0 Children for @root_2" do
			assert_equal 0, @root_2.children.count
		end
		
		should "have 0 Children for @child_1" do
			assert_equal 0, @child_1.children.count
		end
		
		should "have 1 Child for @child_2" do
			assert_equal 1, @child_2.children.count
		end
		
		should "have set @child_2's descendants" do
			assert_equal [ @child_2_1, @child_2_1_1 ], @child_2.descendants.to_a
		end
		
		should "not have a parent for the root nodes" do
			assert_nil @root_1.parent
			assert_nil @root_2.parent
		end
		
		should "have parents for the child nodes" do
			assert_equal @root_1, @child_1.parent
			assert_equal @child_2, @child_2_1.parent
			assert_equal @child_2_1, @child_2_1_1.parent
		end
		
		should "have roots" do
			assert_same_elements [ @root_1, @root_2 ], Category.roots.to_a
		end
		
		
		should "assign parent_id" do
			child	 = Category.create :name => 'child'
			parent = Category.create :name => 'parent'
		
			child.parent_id = parent.id
			child.save
			
			assert_equal [ child ], parent.children.to_a
		
			assert_equal parent.children.first.id, child.id
			assert_equal parent.id, child.parent_id
			assert parent.children.include? child
		
			assert_equal 1, child.depth
			assert_equal [parent.id], child.path
		
			more_deep_child = Category.new(
				:name => 'more deep child',
				:parent_id => child.id
			)
		
			assert more_deep_child.new_record?
			assert more_deep_child.save
			assert !more_deep_child.new_record?
		
			assert_equal child.children.first.id, more_deep_child.id
			assert_equal child.id, more_deep_child.parent_id
			assert child.children.include? more_deep_child
			assert_equal 2, more_deep_child.depth
			assert_equal [parent.id, child.id], more_deep_child.path
		
			assert parent.descendants.include? child
			assert parent.descendants.include? more_deep_child
		
			assert more_deep_child.ancestors.include? child
			assert more_deep_child.ancestors.include? parent
		end
		
		should "assign blank parent_id" do
			@child_1.parent_id = ''
			@child_1.save
		
			assert_nil @child_1.reload.parent_id
			assert_equal 0, @child_1.depth
			assert_equal [], @child_1.path
		
			@child_1.parent_id = nil
			@child_1.save
		
			assert_nil @child_1.reload.parent_id
			assert_equal 0, @child_1.depth
			assert_equal [], @child_1.path
		end
		
		should "replace children list" do
			new_children_list = [ Category.create(:name => "test 1"), Category.create(:name => "test 2") ]
		
			@root_1.children = new_children_list
			assert_equal new_children_list, @root_1.children.to_a
		
			@root_1.children = []
			assert_equal [], @root_1.children.to_a
		end
		
		
		
		context "Destroying a Childless Top Level Node" do
			setup do
				@child_1.destroy
			end
			
			should "reduce the size of @root_1's children to 2" do
				assert_equal 2, @root_1.children.count
			end
			
			should "no longer show in Children" do
				assert_equal [ @child_2, @child_3 ], @root_1.children.to_a
			end
		end
		
		
		context "Destroying a Sub Level Node with Children" do
			setup do
				@child_2_1.destroy
			end
			
			should "not reduce @root_1's children count" do
				assert_equal 3, @root_1.children.count
			end
			
			should "reduce @child_2's children count" do
				assert_equal 0, @child_2.children.count
			end
			
			should "have destroyed it's children" do
				assert_raise(Mongoid::Errors::DocumentNotFound) { Category.find(@child_2_1.id) }
				assert_raise(Mongoid::Errors::DocumentNotFound) { Category.find(@child_2_1_1.id) }
			end
		end
		
		
		context "Clear Children List" do
			setup do
				@root_1.children.clear!
			end
			
			should "have 0 children" do
				assert_equal 0, @root_1.children.size
			end
			
			should "have destroyed all the children" do
				assert_raise(Mongoid::Errors::DocumentNotFound) { Category.find(@child_1.id) }
				assert_raise(Mongoid::Errors::DocumentNotFound) { Category.find(@child_2.id) }
				assert_raise(Mongoid::Errors::DocumentNotFound) { Category.find(@child_2_1.id) }
				assert_raise(Mongoid::Errors::DocumentNotFound) { Category.find(@child_2_1_1.id) }
				assert_raise(Mongoid::Errors::DocumentNotFound) { Category.find(@child_3.id) }
			end
		end
		

		context "node" do
			should "have a root" do
				assert_equal @root_1.root, @root_1
				assert_not_equal @root_1.root, @root_2.root
				assert_equal @root_1, @child_2_1.root
			end
		
			should "have ancestors" do
				assert_equal @root_1.ancestors, []
				assert_equal @child_2.ancestors, [@root_1]
				assert_equal @child_2_1.ancestors, [@root_1, @child_2]
				assert_equal @root_1.self_and_ancestors, [@root_1]
				assert_equal @child_2.self_and_ancestors, [@root_1, @child_2]
				assert_equal @child_2_1.self_and_ancestors, [@root_1, @child_2, @child_2_1]
			end
		
			should "have siblings" do
				assert eql_arrays?(@root_1.siblings, [@root_2])
				assert eql_arrays?(@child_2.siblings, [@child_1, @child_3])
				assert eql_arrays?(@child_2_1.siblings, [])
				assert eql_arrays?(@root_1.self_and_siblings, [@root_1, @root_2])
				assert eql_arrays?(@child_2.self_and_siblings, [@child_1, @child_2, @child_3])
				assert eql_arrays?(@child_2_1.self_and_siblings, [@child_2_1])
			end
		
			should "set depth" do
				assert_equal 0, @root_1.depth
				assert_equal 1, @child_1.depth
				assert_equal 2, @child_2_1.depth
				assert_equal 3, @child_2_1_1.depth
			end
		
			should "have children" do
				assert_same_elements [ @child_1, @child_2, @child_3 ], @root_1.children.to_a
			end
		
			should "have descendants" do
				assert_same_elements [ @child_1, @child_2, @child_3, @child_2_1, @child_2_1_1 ], @root_1.descendants.to_a
				assert_same_elements [ @child_2_1, @child_2_1_1 ], @child_2.descendants.to_a
				assert @child_2_1_1.descendants.empty?
				assert_same_elements [ @root_1, @child_1, @child_2, @child_3, @child_2_1, @child_2_1_1 ], @root_1.self_and_descendants.to_a
				assert_same_elements [ @child_2, @child_2_1, @child_2_1_1 ], @child_2.self_and_descendants.to_a
				assert_same_elements [ @child_2_1, @child_2_1_1 ], @child_2_1.self_and_descendants.to_a
				assert_same_elements [ @child_2_1_1 ], @child_2_1_1.self_and_descendants.to_a
			end
		
			should "be able to tell if ancestor" do
				assert @root_1.is_ancestor_of?(@child_1)
				assert !@root_2.is_ancestor_of?(@child_2_1)
				assert !@child_2.is_ancestor_of?(@child_2)
		
				assert @root_1.is_or_is_ancestor_of?(@child_1)
				assert !@root_2.is_or_is_ancestor_of?(@child_2_1)
				assert @child_2.is_or_is_ancestor_of?(@child_2)
			end
		
			should "be able to tell if descendant" do
				assert !@root_1.is_descendant_of?(@child_1)
				assert @child_1.is_descendant_of?(@root_1)
				assert !@child_2.is_descendant_of?(@child_2)
		
				assert !@root_1.is_or_is_descendant_of?(@child_1)
				assert @child_1.is_or_is_descendant_of?(@root_1)
				assert @child_2.is_or_is_descendant_of?(@child_2)
			end
		
			should "be able to tell if sibling" do
				assert !@root_1.is_sibling_of?(@child_1)
				assert !@child_1.is_sibling_of?(@child_1)
				assert !@child_2.is_sibling_of?(@child_2)
		
				assert !@root_1.is_or_is_sibling_of?(@child_1)
				assert @child_1.is_or_is_sibling_of?(@child_2)
				assert @child_2.is_or_is_sibling_of?(@child_2)
			end
		
			context "when moving" do
				should "recalculate path and depth" do
					@child_2.children << @child_3
					
					assert @child_2.is_or_is_ancestor_of?(@child_3)
					assert @child_3.is_or_is_descendant_of?(@child_2)
					assert @child_2.children.include?(@child_3)
					assert @child_2.descendants.include?(@child_3)
					assert @child_2_1.is_or_is_sibling_of?(@child_3)
					assert_equal 2, @child_3.depth
				end
					
				should "move children on save" do
					@root_2.children << @child_2
					
					@child_2_1.reload
					
					assert @root_2.is_or_is_ancestor_of?(@child_2_1)
					assert @child_2_1.is_or_is_descendant_of?(@root_2)
					assert @root_2.descendants.include?(@child_2_1)
				end
					
				should "check against cyclic graph" do
					assert_equal false, (@child_2_1.children << @root_1)
					assert_equal [ "Can't be children of a descendant" ], @root_1.errors[:base]
				end
			end
		
			should "destroy descendants when destroyed" do
				@child_2.destroy
				assert_nil Category.where(:id => @child_2_1._id).first
			end
		end

	end
end
