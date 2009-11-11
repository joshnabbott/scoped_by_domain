module ScopedByDomain
  SCOPING_EXTENSION = '_for_domain'

  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def scoped_by_domain(model_name, *methods)
      self.instance_eval <<-EOV
        require_dependency model_name.to_s

        def domain_scoped_methods
          @domain_scoped_methods
        end

        def domain_scoped_methods=(methods)
          instance = domain_scoping_model.new
          @domain_scoped_methods ||= methods.inject([]) do |domain_scoped_methods, method|
            return domain_scoped_methods unless instance.respond_to?(method.to_sym)
            domain_scoped_methods << method
            domain_scoped_methods
          end
        end

        def domain_scoping_model
          @domain_scoping_model
        end

        def domain_scoping_model=(model_name)
          @domain_scoping_model = model_name.to_s.classify.constantize
        end

        def domain_scoping_model_table_name
          @domain_scoping_model_table_name ||= @domain_scoping_model.table_name
        end

        def domain_scoping_model_singular_table_name
          @domain_scoping_model_singular_table_name ||= @domain_scoping_model.table_name.singularize
        end
      EOV

      self.domain_scoping_model  = model_name
      self.domain_scoped_methods = methods

      # We'll use this for the belongs_to association
      klass_name = self.class_name

      # Add these to the domain scoping model
      domain_scoping_model.instance_eval do
        before_validation :set_domain_id
        belongs_to :"#{klass_name.tableize.singularize}"
        belongs_to :domain
      end

      domain_scoping_model.class_eval do
        def set_domain_id
          self.domain_id = Domain.current_domain_id if self.domain_id.nil?
        end
      end

      # Now define the associations that will make all this possible
      has_many domain_scoping_model_table_name.to_sym, :dependent => :destroy
      has_one domain_scoping_model_singular_table_name.to_sym, :conditions => 'domain_id = #{Domain.current_domain_id}', :autosave => true
      validates_associated domain_scoping_model_singular_table_name.to_sym

      # And delegate the scoped methods to the scoping model
      # Use delegate_to_nil as it returns the proper default values for the associated record even when it's nil
      domain_scoped_methods.each do |domain_scoped_method|
        delegate :"#{domain_scoped_method}", :to => domain_scoping_model_singular_table_name.to_sym
      end
    end
  end
end
ActiveRecord::Base.instance_eval { include ScopedByDomain }