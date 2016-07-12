class ApplicationController < ActionController::Base
  before_action :run_validations
  
  resource_description do
    param :oauth, String, :desc => "Authorization", :required => false
  end

  def run_validations
    if MoonRaker.configuration.validate == :explicitly
      moon_raker_validations
    end
  end

end
