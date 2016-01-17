module ApipieHelper
  include ActionView::Helpers::TagHelper

      SENTENCE_LINKER = ", associated with the given "
      HAS_PARENT_LINKER = "of the given "

  def heading(title, level=1)
    content_tag("h#{level}") do
      title
    end
  end

  def action_to_sentence action, name
    case action.to_s.downcase
    when "index"
      "Return all the #{name}"
    when "show"
      "Get the requested #{name.singularize}"
    when "create"
      "Create a new #{name.singularize}"
    when "update"
      "Update the requested #{name.singularize}"
    when "destroy"
      "Destroy the requested #{name.singularize}"
    end
  end

  def auto_description resource, class_name, m
    end_sentence = resource[:api_url].scan(/:([\w]*)/).reverse.flatten.map(&:humanize)
    desc = action_to_sentence(m[:name], class_name)
    if end_sentence.count > 0
      desc = "#{desc} #{HAS_PARENT_LINKER} #{end_sentence.join(SENTENCE_LINKER)}"
    end
    desc
  end

end
