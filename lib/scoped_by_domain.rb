module ScopedByDomain
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def scoped_by_domain(&block)
      yield block

      # Add these to the domain scoping model
      @domain_scoping_model.instance_eval do
        before_validation :set_domain_id
        belongs_to :"#{self.class_name.tableize.singularize}"
        belongs_to :domain
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
      delegate *(@domain_scoped_methods << { :to => @domain_scoping_model_singular_table_name.to_sym })

      if domain_scoping_options[:force_association]
        ## Why is this even here? better_delegation should be handling this for us.
        self.class_eval %{
          def after_initialize
            self.#{domain_scoping_model_singular_table_name} ||= self.build_#{domain_scoping_model_singular_table_name}(:domain_id => Domain.current_domain_id)
          end
        }
      end
    end

    def domain_scoping_conditions
      @domain_scoping_conditions ||= if domain_scoping_options[:use_default_domain]
        ["`domain_id` = IFNULL((SELECT `#{domain_scoping_model_table_name}`.`domain_id` FROM `#{domain_scoping_model_table_name}` WHERE `#{domain_scoping_model_table_name}`.`domain_id` = ? LIMIT 1), ?)", Domain.current_domain_id, Domain.default_domain_id]
      else
        ['`domain_id` = ?', Domain.current_domain_id]
      end
    end

    def domain_scoping_options(options = {})
      @domain_scoping_options ||= options.reverse_merge!(default_options)
    end

    def domain_scoping_model(model_name)
      @domain_scoping_model ||= model_name.to_s.classify.constantize
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