module MoonRaker
  class ViewsGenerator < ::Rails::Generators::Base
    source_root File.expand_path('../../../../app/views', __FILE__)
    desc 'Copy MoonRaker views to your application'

    def copy_views
      directory 'moon_raker', 'app/views/moon_raker'
      directory 'layouts/moon_raker', 'app/views/layouts/moon_raker'
    end
  end
end
