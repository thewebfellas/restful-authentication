module Authorization
  module WorkflowRoles
    unless Object.constants.include? "STATEFUL_ROLES_CONSTANTS_DEFINED"
      STATEFUL_ROLES_CONSTANTS_DEFINED = true # sorry for the C idiom
    end
    
    def self.included( recipient )
      recipient.extend( StatefulRolesClassMethods )
      recipient.class_eval do
        include StatefulRolesInstanceMethods
        include Workflow
        
        workflow do
          state :passive do
            event :register, :transitions_to => :pending do
              halt 'Crypted password was blank' if crypted_password.blank?
              halt 'Password was blank' if password.blank?
            end
            event :suspend, :transitions_to => :suspended
            event :delete, :transitions_to => :deleted
          end
          state :pending do
            on_entry do
              make_activation_code
              save!
            end
            event :activate, :transitions_to => :active
            event :suspend, :transitions_to => :suspended
            event :delete, :transitions_to => :deleted
          end
          state :active do
            on_entry do
              do_activate
              save!
            end
            event :suspend, :transitions_to => :suspended
            event :delete, :transitions_to => :deleted
          end
          state :suspended do
            event :delete, :transitions_to => :deleted
            event :unsuspend, :transitions_to => :active do
              fall_through if activated_at.blank?
            end
            event :unsuspend, :transitions_to => :pending do
              fall_through if activation_code.blank?
            end
            event :unsuspend, :transitions_to => :passive
          end
          state :deleted do
            on_entry do
              do_delete
              save!
            end
          end
        end
      end
    end

    module StatefulRolesClassMethods
    end # class methods

    module StatefulRolesInstanceMethods
      # Returns true if the user has just been activated.
      def recently_activated?
        @activated
      end
      def do_delete
        self.deleted_at = Time.now.utc
      end

      def do_activate
        @activated = true
        self.activated_at = Time.now.utc
        self.deleted_at = self.activation_code = nil
      end
    end # instance methods
  end
end
