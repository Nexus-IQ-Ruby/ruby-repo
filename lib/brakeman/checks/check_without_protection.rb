require 'brakeman/checks/base_check'

#Check for bypassing mass assignment protection
#with without_protection => true
#
#Only for Rails 3.1
class Brakeman::CheckWithoutProtection < Brakeman::BaseCheck
  Brakeman::Checks.add self

  @description = "Check for mass assignment using without_protection"

  def run_check
    if version_between? "0.0.0", "3.0.99"
      return
    end

    models = []
    tracker.models.each do |name, m|
      if parent? m, :"ActiveRecord::Base"
        models << name
      end
    end

    return if models.empty?

    Brakeman.debug "Finding all mass assignments"
    calls = tracker.find_call :targets => models, :methods => [:new,
      :attributes=, 
      :update_attribute, 
      :update_attributes, 
      :update_attributes!,
      :create,
      :create!]

    Brakeman.debug "Processing all mass assignments"
    calls.each do |result|
      process_result result
    end
  end

  #All results should be Model.new(...) or Model.attributes=() calls
  def process_result res
    call = res[:call]
    last_arg = call[3][-1]

    if hash? last_arg and not call.original_line and not duplicate? res

      if value = hash_access(last_arg, :without_protection)
        if true? value
          add_result res

          if include_user_input? call[3]
            confidence = CONFIDENCE[:high]
          else
            confidence = CONFIDENCE[:med]
          end

          warn :result => res, 
            :warning_type => "Mass Assignment", 
            :message => "Unprotected mass assignment",
            :line => call.line,
            :code => call, 
            :confidence => confidence

        end
      end
    end
  end
end
