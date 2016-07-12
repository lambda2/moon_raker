module MoonRaker
  class Railtie < Rails::Railtie
    initializer 'moon_raker.controller_additions' do
      ActiveSupport.on_load :action_controller do
        extend MoonRaker::DSL::Controller
      end
    end
  end
end
