require "mongoid"
require "mongoid/acts_as_tree"

class OrderedCategory
  include Mongoid::Document
  include Mongoid::Acts::Tree

  field :name, :type => String
  field :value, :type => Integer

  acts_as_tree :order => [['value', 'asc']]
end

