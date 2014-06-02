# module FixDefinition
#   module FixTagDefinition
#     attr_accessor :name, :tag
#   end

#   module FixContainerDefinition
#     def self.inclduded(base)
#       base.send(:include, ::FixDefinition::FixTagDefinition)
#       base.send(:extend, ClassMethods)
#     end

#     module ClassMethods
#       def tags(message)
#         message.split(SOH).map do |tag_equals_value|
#           FixTag.new(tag_equals_value)
#         end
#       end
#     end

#     def parse(message)
#       parse_tags(self.class.tags(message))
#     end

#     attr_accessor :fields, :groups
#   end

#   class FixFieldDefinition
#     include FixTagDefinition

#     def initialize(name, tag)
#       @name = name
#       @tag = tag
#     end
#   end

#   class FixTag
#     attr_accessor :tag, :value

#     def initialize(*args)
#       if args.size == 1
#         @tag, @value = args.first.split(/=/)
#       elsif args.size == 2
#         @tag,@value = args
#       else
#         raise ArgumentError, '1 or 2 arguments only'
#       end
#     end
#   end

#   class FixGroupDefinition
#     include FixContainerDefinition

#     def initialize(name, tag)
#       @name = name
#       @tag = tag
#     end

#     def parse_tags(tags)

#       my_index = tags.index { |ft| ft.tag == tag }
#       expected = tags[my_index].value.to_i
#       begin_index = my_index + 1
#       subset = tags[begin_index..-1]
#       end_index = subset.index { |ft| !tagtree.include?(ft.tag) } - 1
#       all_my_tags = subset[0..end_index]
#       just_my_tags = all_my_tags.select { |ft| fields.map(&:tag).include?(ft.tag) }

#       _groups = groups.select do |gd|
#         tags.any? do |ft|
#           ft.tag == gd.tag
#         end
#       end.map do |gd|
#         gd.parse_tags(all_my_tags)
#       end
#     end

#     def tagtree
#       (groups.tagtree.flatten + [fields]).flatten.uniq
#     end
#   end

#   class FixMessageDefinition
#     include FixContainerDefinition

#     attr_accessor :element

#     def initialize(name, options = {})
#       @name = name
#       @element = options[:element]
#     end

#     def parse_tags(tags)
#       # a message definition may have groups, fields or components
#       # a component my have groups, fields or components
#       # a group may have groups or fields.  maybe components?
      
    
#     end

#     class << self
#     end
#   end
# end
