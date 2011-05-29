# here we should require sub_category.rb because of wrong require order
require File.join(File.dirname(__FILE__), 'sub_category.rb')
class SubCategory2 < SubCategory

end
