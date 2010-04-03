# TODO: handling of default domains should be moved to the data layer as a mysql trigger
module ScopedByDomain
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def scoped_by_domain(&block)
      yield block

      # Gonna need to know this in a few cases below
      scoped_klass = self

      # Add these to the domain scoping model
      @domain_scoping_model.instance_eval do
        before_validation_on_create :set_domain_id
        belongs_to :"#{scoped_klass.class_name.tableize.singularize}"
        belongs_to :domain
        validates_presence_of :domain_id
      end

      @domain_scoping_model.class_eval do
        def set_domain_id
          self.domain_id = Domain.current_domain_id
        end
      end

      # Now define the associations that will make all this possible
      has_many self.domain_scoping_model_table_name.to_sym, :dependent => :destroy
      has_one self.domain_scoping_model_singular_table_name.to_sym, :conditions => self.domain_scoping_conditions, :autosave => true
      validates_associated self.domain_scoping_model_singular_table_name.to_sym

      # And delegate the scoped methods to the scoping model
      @domain_scoped_methods.each do |method_to_scope|
        methods = [method_to_scope]
        methods << "#{method_to_scope}=" unless method_to_scope.to_s.last == "?"
        delegate *(methods << { :to => @domain_scoping_model_singular_table_name.to_sym, :allow_nil => true })
      end

       self.class_eval %{
         def after_initialize
           self.#{domain_scoping_model_singular_table_name} ||= self.build_#{domain_scoping_model_singular_table_name}(:domain_id => Domain.current_domain_id)
         end
       }
    end

    def domain_scoping_conditions
      @domain_scoping_conditions ||= if domain_scoping_options[:use_default_domain]
        '`domain_id` = (SELECT (CASE count(*) WHEN 0 THEN #{Domain.default_domain_id} ELSE #{Domain.current_domain_id} END) AS `domain_id` FROM #{self.class.domain_scoping_model_table_name} WHERE `#{self.class.domain_scoping_model_primary_key_name}` = #{self.id} AND domain_id = #{Domain.current_domain_id})'
      else
        'domain_id = #{Domain.current_domain_id}'
      end
    end

    def domain_scoping_options(options = {})
      @domain_scoping_options ||= options.reverse_merge!(default_options)
    end

    def domain_scoping_model(model_name = nil)
      @domain_scoping_model ||= model_name.to_s.classify.constantize
    end

    def domain_scoping_model_primary_key_name
      @domain_scoping_model_primary_key_name ||= self.reflect_on_association(:"#{domain_scoping_model_singular_table_name}").primary_key_name
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

    def default_options
      {
        :force_association => true,
        :use_default_domain => false
      }
    end
  end
end
ActiveRecord::Base.instance_eval { include ScopedByDomain }