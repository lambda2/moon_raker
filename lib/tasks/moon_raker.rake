# -*- coding: utf-8 -*-
require 'fileutils'

namespace :moon_raker do
  desc 'Generate static documentation'
  # You can specify OUT=output_base_file to have the following structure:
  #
  #    output_base_file.html
  #    output_base_file-onepage.html
  #    output_base_file
  #    | - resource1.html
  #    | - resource1
  #    | - | - method1.html
  #    | - | - method2.html
  #    | - resource2.html
  #
  # By default OUT="#{Rails.root}/doc/apidoc"
  task :static, [:version] => :environment do |_t, args|
    with_loaded_documentation do
      args.with_defaults(version: MoonRaker.configuration.default_version)
      out = ENV['OUT'] || File.join(::Rails.root, MoonRaker.configuration.doc_path, 'apidoc')
      subdir = File.basename(out)
      copy_jscss(out)
      MoonRaker.configuration.version_in_url = false
      ([nil] + MoonRaker.configuration.languages).each do |lang|
        I18n.locale = lang || MoonRaker.configuration.default_locale
        MoonRaker.url_prefix = "./#{subdir}"
        doc = MoonRaker.to_json(args[:version], nil, nil, lang)
        doc[:docs][:link_extension] = "#{lang_ext(lang)}.html"
        generate_one_page(out, doc, lang)
        generate_plain_page(out, doc, lang)
        generate_index_page(out, doc, false, false, lang)
        MoonRaker.url_prefix = "../#{subdir}"
        generate_resource_pages(args[:version], out, doc, false, lang)
        MoonRaker.url_prefix = "../../#{subdir}"
        generate_method_pages(args[:version], out, doc, false, lang)
      end
    end
  end

  desc 'Generate static documentation json'
  task :static_json, [:version] => :environment do |_t, args|
    with_loaded_documentation do
      args.with_defaults(version: MoonRaker.configuration.default_version)
      out = ENV['OUT'] || File.join(::Rails.root, MoonRaker.configuration.doc_path, 'apidoc')
      ([nil] + MoonRaker.configuration.languages).each do |lang|
        doc = MoonRaker.to_json(args[:version], nil, nil, lang)
        generate_json_page(out, doc, lang)
      end
    end
  end

  # By default the full cache is built.
  # It is possible to generate index resp. resources only with
  # rake moon_raker:cache cache_part=index (resources resp.)
  # Default output dir ('public/moon_raker_cache') can be changed with OUT=/some/dir
  desc 'Generate cache to avoid production dependencies on markup languages'
  task cache: :environment do
    puts "#{Time.now} | Started"
    cache_part = ENV['cache_part']
    generate_index = (cache_part == 'resources' ? false : true)
    generate_resources = (cache_part == 'index' ? false : true)
    with_loaded_documentation do
      puts "#{Time.now} | Documents loaded..."
      ([nil] + MoonRaker.configuration.languages).each do |lang|
        I18n.locale = lang || MoonRaker.configuration.default_locale
        puts "#{Time.now} | Processing docs for #{lang}"
        cache_dir = ENV['OUT'] || MoonRaker.configuration.cache_dir
        subdir = MoonRaker.configuration.doc_base_url.sub(/\A\//, '')
        subdir_levels = subdir.split('/').length
        subdir_traversal_prefix = '../' * subdir_levels
        file_base = File.join(cache_dir, MoonRaker.configuration.doc_base_url)

        if generate_index
          MoonRaker.url_prefix = "./#{subdir}"
          doc = MoonRaker.to_json(MoonRaker.configuration.default_version, nil, nil, lang)
          doc[:docs][:link_extension] = (lang ? ".#{lang}.html" : '.html')
          generate_index_page(file_base, doc, true, false, lang)
        end
        MoonRaker.available_versions.each do |version|
          file_base_version = File.join(file_base, version)
          MoonRaker.url_prefix = "#{subdir_traversal_prefix}#{subdir}"
          doc = MoonRaker.to_json(version, nil, nil, lang)
          doc[:docs][:link_extension] = (lang ? ".#{lang}.html" : '.html')

          generate_index_page(file_base_version, doc, true, true, lang) if generate_index
          next unless generate_resources
          MoonRaker.url_prefix = "../#{subdir_traversal_prefix}#{subdir}"
          generate_resource_pages(version, file_base_version, doc, true, lang)
          MoonRaker.url_prefix = "../../#{subdir_traversal_prefix}#{subdir}"
          generate_method_pages(version, file_base_version, doc, true, lang)
        end
      end
    end
    puts "#{Time.now} | Finished"
  end

  # Attempt to use the Rails application views, otherwise default to built in views
  def renderer
    return @moon_raker_renderer if @moon_raker_renderer
    base_path = if File.directory?("#{Rails.root}/app/views/moon_raker/moon_rakers")
                  "#{Rails.root}/app/views/moon_raker/moon_rakers"
                else
                  File.expand_path('../../../app/views/moon_raker/moon_rakers', __FILE__)
                end
    layouts_path = File.expand_path("../../../app/views/layouts", __FILE__)
    @moon_raker_renderer = ActionView::Base.new([base_path, layouts_path])
    @moon_raker_renderer.singleton_class.send(:include, MoonRakerHelper)
    @moon_raker_renderer
  end

  def render_page(file_name, template, variables, layout = 'moon_raker')
    av = renderer
    File.open(file_name, 'w') do |f|
      variables.each do |var, val|
        av.instance_variable_set("@#{var}", val)
      end
      f.write av.render(
        :template => "#{template}",
        :layout => (layout && "moon_raker/#{layout}"))
    end
  end

  def generate_json_page(file_base, doc, lang = nil)
    FileUtils.mkdir_p(file_base) unless File.exist?(file_base)

    filename = "schema_moon_raker#{lang_ext(lang)}.json"
    File.open("#{file_base}/#{filename}", 'w') { |file| file.write(JSON.pretty_generate(doc)) }
  end

  def generate_one_page(file_base, doc, lang = nil)
    FileUtils.mkdir_p(File.dirname(file_base)) unless File.exist?(File.dirname(file_base))

    render_page("#{file_base}-onepage#{lang_ext(lang)}.html", 'static', doc: doc[:docs],
                                                                        language: lang, languages: MoonRaker.configuration.languages)
  end

  def generate_plain_page(file_base, doc, lang = nil)
    FileUtils.mkdir_p(File.dirname(file_base)) unless File.exist?(File.dirname(file_base))

    render_page("#{file_base}-plain#{lang_ext(lang)}.html", 'plain', { doc: doc[:docs],
                                                                       language: lang, languages: MoonRaker.configuration.languages }, nil)
  end

  def generate_index_page(file_base, doc, include_json = false, show_versions = false, lang = nil)
    FileUtils.mkdir_p(File.dirname(file_base)) unless File.exist?(File.dirname(file_base))
    versions = show_versions && MoonRaker.available_versions
    render_page("#{file_base}#{lang_ext(lang)}.html", 'index', doc: doc[:docs],
                                                               versions: versions, language: lang, languages: MoonRaker.configuration.languages)

    File.open("#{file_base}#{lang_ext(lang)}.json", 'w') { |f| f << doc.to_json } if include_json
  end

  def generate_resource_pages(version, file_base, doc, include_json = false, lang = nil)
    doc[:docs][:resources].each do |resource_name, _|
      resource_file_base = File.join(file_base, resource_name.to_s)
      FileUtils.mkdir_p(File.dirname(resource_file_base)) unless File.exist?(File.dirname(resource_file_base))

      doc = MoonRaker.to_json(version, resource_name, nil, lang)
      doc[:docs][:link_extension] = (lang ? ".#{lang}.html" : '.html')
      render_page("#{resource_file_base}#{lang_ext(lang)}.html", 'resource', doc: doc[:docs],
                                                                             resource: doc[:docs][:resources].first, language: lang, languages: MoonRaker.configuration.languages)
      File.open("#{resource_file_base}#{lang_ext(lang)}.json", 'w') { |f| f << doc.to_json } if include_json
    end
  end

  def generate_method_pages(version, file_base, doc, include_json = false, lang = nil)
    doc[:docs][:resources].each do |resource_name, resource_params|
      resource_params[:methods].each do |method|
        method_file_base = File.join(file_base, resource_name.to_s, method[:name].to_s)
        FileUtils.mkdir_p(File.dirname(method_file_base)) unless File.exist?(File.dirname(method_file_base))

        doc = MoonRaker.to_json(version, resource_name, method[:name], lang)
        doc[:docs][:link_extension] = (lang ? ".#{lang}.html" : '.html')
        render_page("#{method_file_base}#{lang_ext(lang)}.html", 'method', doc: doc[:docs],
                                                                           resource: doc[:docs][:resources].first,
                                                                           method: doc[:docs][:resources].first[:methods].first,
                                                                           language: lang,
                                                                           languages: MoonRaker.configuration.languages)

        File.open("#{method_file_base}#{lang_ext(lang)}.json", 'w') { |f| f << doc.to_json } if include_json
      end
    end
  end

  def with_loaded_documentation
    MoonRaker.configuration.use_cache = false # we don't want to skip DSL evaluation
    MoonRaker.reload_documentation
    yield
  end

  def copy_jscss(dest)
    src = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'app', 'public', 'moon_raker'))
    FileUtils.mkdir_p dest
    FileUtils.cp_r "#{src}/.", dest
  end

  def lang_ext(lang = nil)
    lang ? ".#{lang}" : ''
  end

  desc 'Generate CLI client for API documented with moon_raker gem. (deprecated)'
  task :client do
    puts <<MESSAGE
The moon_raker gem itself doesn't provide client code generator. See
https://github.com/Pajk/moon_raker-rails/wiki/CLI-client for more information on
how to write your own generator.
MESSAGE
  end

  def plaintext(text)
    text.gsub(/<.*?>/, '').tr("\n", ' ').strip
  end

  desc 'Update api description in controllers base on routes'
  task update_from_routes: [:environment] do
    MoonRaker.configuration.force_dsl = true
    ignored = MoonRaker.configuration.ignored_by_recorder
    with_loaded_documentation do
      apis_from_routes = MoonRaker::Extractor.apis_from_routes
      apis_from_routes.each do |(controller, action), apis|
        next if ignored.include?(controller)
        next if ignored.include?("#{controller}##{action}")
        MoonRaker::Extractor::Writer.update_action_description(controller.constantize, action) do |u|
          u.update_apis(apis)
        end
      end
    end
  end

  desc 'Convert your examples from the old yaml into the new json format'
  task convert_examples: :environment do
    yaml_examples_file = File.join(Rails.root, MoonRaker.configuration.doc_path, 'moon_raker_examples.yml')
    if File.exist?(yaml_examples_file)
      # if SafeYAML gem is enabled, it will load examples as an array of Hash, instead of hash
      examples = if defined? SafeYAML
                   YAML.load_file(yaml_examples_file, safe: false)
                 else
                   YAML.load_file(yaml_examples_file)
                 end
    else
      examples = {}
    end
    MoonRaker::Extractor::Writer.write_recorded_examples(examples)
  end
end
