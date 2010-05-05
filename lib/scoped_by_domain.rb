# TODO: Add documentation so this is easy to figure out
# TODO: Fix the hackery (eg: has_default_record?)
module ScopedByDomain
  def self.included(base)
    base.extend(ClassMethods)
  end

  # module Domainable
  #   def domain_scoping_options(options = {})
  #     @domain_scoping_options ||= options.reverse_merge!(default_options)
  #   end
  # 
  #   def default_options
  #     {
  #       :force_association => true,
  #       :use_default_domain => false
  #     }
  #   end
  # end

  module ClassMethods
    def scoped_by_domain(&block)
      # extend Domainable
      # include Domainable

      yield block

      # Gonna need to know this in a few cases below
      scoped_klass = self

      # Add these to the domain scoping model
      @domain_scoping_model.instance_eval do
        # include Domainable
        attr_protected :domain_id
        before_validation_on_create :set_domain_id
        belongs_to :"#{scoped_klass.class_name.tableize.singularize}"
        belongs_to :domain
        validates_presence_of :domain_id
      end

      @domain_scoping_model.class_eval do
        def has_default_record?
          foreign_key = self.class.name.tableize.gsub(/_for_domains/, '_id')
          self.class.exists?(:domain_id => Domain.default_domain_id, :"#{foreign_key}" => self.send(:"#{foreign_key}"))
        end

        def set_domain_id
          # self.domain_id = if self.domain_scoping_options[:use_default_domain]
          #   self.has_default_record? ? Domain.current_domain_id : Domain.default_domain_id
          # else
          #   Domain.current_domain_id
          # end
          self.domain_id = Domain.current_domain_id
        end
      end

      # Now define the associations that will make all this possible
      has_many self.domain_scoping_model_table_name.to_sym, :dependent => :destroy
      # Monster hacks below.
      # http://dev.rubyonrails.org/ticket/6500 for the ugly conditions statements
      has_one self.domain_scoping_model_singular_table_name.to_sym, :conditions => '#{self.respond_to?(:aliased_table_name) ? "#{self.aliased_table_name}." : ""}domain_id = #{Domain.current_domain_id}', :autosave => true
      has_one "default_#{self.domain_scoping_model_singular_table_name}".to_sym, :class_name => domain_scoping_model_singular_table_name.classify, :conditions => '#{self.respond_to?(:aliased_table_name) ? "#{self.aliased_table_name}." : ""}domain_id = #{Domain.default_domain_id}'

      validates_associated self.domain_scoping_model_singular_table_name.to_sym
      attr_accessor :delegated_initialize_attributes

      # And delegate the scoped methods to the scoping model
      @domain_scoped_methods.each do |method_to_scope|
        methods = [method_to_scope]
        methods << "#{method_to_scope}=" unless method_to_scope.to_s.last == "?"
        delegate *(methods << { :to => @domain_scoping_model_singular_table_name.to_sym, :allow_nil => true })
      end

      self.class_eval <<-RUBY
        def initialize(attributes = nil)
          self.delegated_initialize_attributes = attributes.reject { |key, value| !self.class.domain_scoped_methods.include?(key) }
          super
        end

        def after_initialize
          self.build_#{domain_scoping_model_singular_table_name}(self.delegated_initialize_attributes) unless self.#{domain_scoping_model_singular_table_name}
        end
      RUBY

      # Default domain support
      if self.domain_scoping_options[:use_default_domain]
        self.class_eval <<-RUBY
          named_scope :for_current_domain, :include => [:#{domain_scoping_model_singular_table_name}, :default_#{domain_scoping_model_singular_table_name}]

          class << self
            def find_every_with_domain(options)
              self.with_scope(:find => {:include => [:#{domain_scoping_model_singular_table_name}, :default_#{domain_scoping_model_singular_table_name}]}) do
                find_every_without_domain(options)
              end
            end
            alias_method_chain :find_every, :domain
          end

          def after_find
            self.build_#{domain_scoping_model_singular_table_name}(self.default_#{domain_scoping_model_singular_table_name}.attributes) unless self.#{domain_scoping_model_singular_table_name}
          end
        RUBY
      else
        self.class_eval <<-RUBY
          named_scope :for_current_domain, :include => [:#{domain_scoping_model_singular_table_name}]

          class << self
            def find_every_with_domain(options)
              self.with_scope(:find => {:include => [:#{domain_scoping_model_singular_table_name}]}) do
                find_every_without_domain(options)
              end
            end
            alias_method_chain :find_every, :domain
          end

          def after_find
            self.build_#{domain_scoping_model_singular_table_name} unless self.#{domain_scoping_model_singular_table_name}
          end
        RUBY
      end
    end

    def domain_scoping_options(options = {})
      @domain_scoping_options ||= options.reverse_merge!(default_options)
    end

    def default_options
      {
        :force_association => true,
        :use_default_domain => false
      }
    end

    def domain_scoping_model(model_name = nil)
      @domain_scoping_model ||= model_name.to_s.classify.constantize
    end

    def domain_scoping_model_primary_key_name
      @domain_scoping_model_primary_key_name ||= self.name.underscore + '_id'
    end

    def domain_scoped_methods(*methods)
      @domain_scoped_methods ||= methods
    end

    def domain_scoping_model_table_name
      @domain_scoping_model_table_name ||= @domain_scoping_model.table_name
    end

    def domain_scoping_model_singular_table_name
      @domain_scoping_model_singular_table_name ||= @domain_scoping_model.table_name.singularize
    end
  end
end
ActiveRecord::Base.instance_eval { include ScopedByDomain }


#   def count_with_default_domain(*args)
#     self.with_scope(:find => { :include => :#{domain_scoping_model_table_name}, :conditions => "`#{domain_scoping_model_table_name}`.`domain_id` = (SELECT (CASE count(*) WHEN 0 THEN #{Domain.default_domain_id} ELSE #{Domain.current_domain_id} END) AS `domain_id` FROM `#{domain_scoping_model_table_name}` WHERE `#{self.name.underscore + '_id'}` = `#{self.table_name}`.`id` AND `#{domain_scoping_model_table_name}`.`domain_id` = #{Domain.current_domain_id})" }) do
#       count_without_default_domain(*args)
#     end
#   end
#   alias_method_chain :count, :default_domain
# 
#   def find_with_default_domain(*args)
#     options = args.extract_options!
#     self.with_scope(:find => { :include => :#{domain_scoping_model_table_name}, :conditions => "`#{domain_scoping_model_table_name}`.`domain_id` = (SELECT (CASE count(*) WHEN 0 THEN #{Domain.default_domain_id} ELSE #{Domain.current_domain_id} END) AS `domain_id` FROM `#{domain_scoping_model_table_name}` WHERE `#{self.name.underscore + '_id'}` = `#{self.table_name}`.`id` AND `#{domain_scoping_model_table_name}`.`domain_id` = #{Domain.current_domain_id})" }) do
#       find_without_default_domain(args.first, options)
#     end
#   end
#   alias_method_chain :find, :default_domain
# end
# 
# def build_#{domain_scoping_model_singular_table_name}_with_default(attributes = {})
#   if self.#{domain_scoping_model_table_name}.exists?(:domain_id => Domain.default_domain_id)
#     default_attributes = self.#{domain_scoping_model_table_name}.default.attributes
#     build_#{domain_scoping_model_singular_table_name}_without_default(default_attributes)
#   else
#     build_#{domain_scoping_model_singular_table_name}_without_default(attributes)
#   end
# end
# alias_method_chain(:build_#{domain_scoping_model_singular_table_name}, :default)