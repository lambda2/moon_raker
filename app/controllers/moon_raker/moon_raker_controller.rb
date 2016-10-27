module MoonRaker
  class MoonRakerController < ActionController::Base
    caches_page :index, gzip: true if MoonRaker.configuration.static_caching

    include ActionView::Context
    include MoonRakerHelper

    layout MoonRaker.configuration.layout

    around_filter :set_script_name
    # before_filter :authenticate

    # skip_authentication


    def authenticate
      if MoonRaker.configuration.authenticate
        instance_eval(&MoonRaker.configuration.authenticate)
      end
    end

    def guides
      @section = params[:section] || :specification

      title = @section.to_s.humanize
      desc = "Guides for #{title}"
      set_meta_tags({
        title: title,
        description: desc,
        keywords: [title, '42', 'API', 'guides'].join(', '),
        author: "https://plus.google.com/u/0/115378296196014576465",
        publisher: "https://plus.google.com/u/0/115378296196014576465",
        og: {
          title: title,
          description: desc
        },
        twitter: {
          card: "summary",
          site: "@42born2code",
          title: title,
          description: desc
        }
      })

      begin
        render "moon_raker/static/#{@section}", layout: "moon_raker/guides"
      rescue ActionView::MissingTemplate
        render 'moon_raker_404', :status => 404
      end
    end

    def index
      params[:version] ||= MoonRaker.configuration.default_version

      get_format

      respond_to do |format|

        if MoonRaker.configuration.use_cache?
          render_from_cache
          return
        end

        @language = get_language

        MoonRaker.load_documentation if MoonRaker.configuration.reload_controllers? || (Rails.version.to_i >= 4.0 && !Rails.application.config.eager_load)

        I18n.locale = @language
        @doc = MoonRaker.to_json(params[:version], params[:resource], params[:method], @language)

        @doc = authorized_doc

        format.json do
          if @doc
            render :json => @doc
          else
            head :not_found
          end
        end

        format.html do
          unless @doc
            render 'moon_raker_404', :status => 404
            return
          end

          @versions = MoonRaker.available_versions
          @doc = @doc[:docs]
          @doc[:link_extension] = (@language ? ".#{@language}" : '')+MoonRaker.configuration.link_extension
          if @doc[:resources].blank?
            render "getting_started" and return
          end
          @resource = @doc[:resources].first if params[:resource].present?
          @method = @resource[:methods].first if params[:method].present?
          @languages = MoonRaker.configuration.languages


          title = ""
          title = @resource[:name] if @resource
          title = "#{@method[:name].gsub(/^_/, "")} of #{title} (#{@method[:apis].count} endpoints)" if @method

          description = ""
          description = @resource[:description] if @resource
          description = @method[:desription] if @method

          tags = []
          tags << @resource[:name] if @resource
          tags << @method[:name] if @method
          tags << ["42", "api"]

          path = MoonRaker.configuration.doc_base_url.dup
          path << "/" << params[:version] if params[:version].present?
          path << "/" << params[:resource] if params[:resource].present?
          path << "/" << params[:method] if params[:method].present?

          author = {
            "@type": "Person",
            first_name: 'André',
            last_name: 'Aubin',
            username: 'andral',
            gender: 'male',
            "name": "André Aubin",
            "url": "https://plus.google.com/u/0/115378296196014576465",
            fb: {
              profile_id: 'andre.awbin'
            }
          }

          article = {
            published_time: Date.parse("2016-02-10"),
            modified_time: Date::today,
            author: author,
            "datePublished": Date.parse("2016-02-10"),
            "dateModified": Date::today,
            "description": description,
            "keywords": tags.join(', '),
            tag: tags
          }

          additional = {}
          if @resource && @method
            additional = {
              label1: "Method",
              data1: @method[:apis].try(:first).try(:fetch, :http_method, :GET).to_s,
              label2: "Endpoint",
              data2: "#{@resource[:name]}##{@method[:name].gsub(/^_/, "")}",
            }
          end

          set_meta_tags({
            title: title,
            description: description,
            keywords: tags.join(', '),
            author: "https://plus.google.com/u/0/115378296196014576465",
            publisher: "https://plus.google.com/u/0/115378296196014576465",
            og: {
              title: title,
              type: 'article',
              description: description,
              author: author,
              url: "#{path}.html",
              article: article
            },
            twitter: {
              card: "summary",
              site: "@42born2code",
              title: title,
              url: "#{path}.html",
              description: description
            }.merge(additional)
          })

          if @resource && @method
            render 'method'
          elsif @resource
            render 'resource'
          elsif params[:resource].present? || params[:method].present?
            render 'moon_raker_404', :status => 404
          else
            render 'index'
          end
        end
      end
    end

    def moon_raker_checksum
    end

    private
    helper_method :heading

    def get_language
      lang = nil
      [:resource, :method, :version].each do |par|
        if params[par]
          splitted = params[par].split('.')
          if splitted.length > 1 && MoonRaker.configuration.languages.include?(splitted.last)
            lang = splitted.last
            params[par].sub!(".#{lang}", '')
          end
        end
      end
      lang
    end

    def authorized_doc

      return @doc unless MoonRaker.configuration.authorize

      new_doc = { :docs => @doc[:docs].clone }

      new_doc[:docs][:resources] = @doc[:docs][:resources].select do |k, v|
        if instance_exec(k, nil, v, &MoonRaker.configuration.authorize)
          v[:methods] = v[:methods].select do |h|
            instance_exec(k, h[:name], h, &MoonRaker.configuration.authorize)
          end
          true
        else
          false
        end
      end

      new_doc
    end

    def get_format
      [:resource, :method, :version].each do |par|
        if params[par]
          params[:format] = :html unless params[par].sub!('.html', '').nil?
          params[:format] = :json unless params[par].sub!('.json', '').nil?
        end
      end
      request.format = params[:format] if params[:format]
    end

    def render_from_cache
      path = MoonRaker.configuration.doc_base_url.dup
      # some params can contain dot, but only one in row
      if [:resource, :method, :format, :version].any? { |p| params[p].to_s.gsub(".", "") =~ /\W/ || params[p].to_s =~ /\.\./ }
        head :bad_request and return
      end

      path << "/" << params[:version] if params[:version].present?
      path << "/" << params[:resource] if params[:resource].present?
      path << "/" << params[:method] if params[:method].present?
      if params[:format].present?
        path << ".#{params[:format]}"
      else
        path << ".html"
      end

      # we sanitize the params before so in ideal case, this condition
      # will be never satisfied. It's here for cases somebody adds new
      # param into the path later and forgets about sanitation.
      if path =~ /\.\./
        head :bad_request and return
      end

      cache_file = File.join(MoonRaker.configuration.cache_dir, path)
      if File.exists?(cache_file)
        content_type = case params[:format]
                       when "json" then "application/json"
                       else "text/html"
                       end
        send_file cache_file, :type => content_type, :disposition => "inline"
      else
        Rails.logger.error("API doc cache not found for '#{path}'. Perhaps you have forgot to run `rake moon_raker:cache`")
        head :not_found
      end
    end

    def set_script_name
      MoonRaker.request_script_name = request.env["SCRIPT_NAME"]
      yield
    ensure
      MoonRaker.request_script_name = nil
    end
  end
end
