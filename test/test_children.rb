require 'helper'
require 'set'

class TestMongoidActsAsTree < Test::Unit::TestCase

	context "Create Children Criteria" do
		setup do
			@category = Category.create(:name => "Root 2")
			@children = Mongoid::Acts::Tree::Children.new(@category, Category)
		end
		
		should "have initialized Children subtype of Mongoid::Criteria" do
			assert_instance_of Mongoid::Acts::Tree::Children, @children
			assert_kind_of Mongoid::Criteria, @children
		end
		
		should "have set the selector" do
			expected_selector = { "parent_id" => @category.id }
			assert_equal expected_selector, @children.selector
		end
		
		should "have defaulted the ordering to nothing" do
			assert_equal Array.new, @children.sort
		end
	end
	
	
	context "Build Child" do
		setup do
			@root = Category.create(:name => "Root")
			@child = @root.children.build(:name => "Child 1")
		end
		
		should "set @root as the parent for the child" do
			assert_equal @root, @child.parent
		end
		
		should "not have saved @child1 into @root's children" do
			assert_equal Array.new, @root.children.to_a
		end
		
		should "still have zero children" do
			assert_equal 0, @root.children.size
			assert_equal 0, @root.children.count
		end
		
		should "not have saved @child" do
			assert_raise(Mongoid::Errors::DocumentNotFound) { Category.find(@child.id) }
		end
	end
	
	
	context "Create Child" do
		setup do
			@root = Category.create(:name => "Root")
			@child = @root.children.create(:name => "Child 1")
		end
		
		should "set @root as the parent for the child" do
			assert_equal @root, @child.parent
		end
		
		should "have saved @child1 into @root's children" do
			assert_equal [ @child ], @root.children.to_a
		end	
		
		should "have 1 child" do
			assert_equal 1, @root.children.size
			assert_equal 1, @root.children.count
		end
	end
	
	
	context "Add Created Child via <<" do
		setup do
			@root = Category.create(:name => "The Root")
			@child = Category.create(:name => "of All Evil")
			@root.children << @child
		end
		
		should "have updated @child to have @root_1 as it's parent" do
			assert_equal @root, @child.parent
			assert_equal @root, @child.reload.parent
		end
		
		should "be able to access @child through children of @root" do
			assert_equal [ @child ], @root.children.to_a
		end
		
		should "have 1 child" do
			assert_equal 1, @root.children.size
			assert_equal 1, @root.children.count
		end
	end
	
	
	context "Cyclic Children" do
		
		context "Root adding to Root" do
			setup do
				@root = Category.create(:name => "Root")
			end
			
			should "not save under itself" do
				assert_equal false, @root.children << @root
			end
		end
		
	end

end
