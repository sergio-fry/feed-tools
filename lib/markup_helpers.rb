require 'nokogiri'
require 'redcarpet'
require 'active_support'
require 'active_support/core_ext/object/blank'
require 'sanitize'

module MarkupHelpers
  def cleanup_html(html_or_doc, rules=nil)
    rules.each_with_index do |line, index|
      match = line.match(/^([^\s]+)\s+([^\s]+)\s+(.*)/)

      if match
        cmd = match[1]
        args = [match[2], match[3].strip]

        case cmd
        when "remove"

          case args[0]
          when "regexp"
            regexp = eval(args[1])

            html_or_doc = to_html(html_or_doc).gsub regexp, ""
          when "css"
            html_or_doc = to_doc(html_or_doc)
            html_or_doc.css(args[1]).each(&:remove)
          else
            raise "unknown remove type '#{args[0]}': '#{line}'"
          end

        when "select"
          case args[0]
          when "css"
            html_or_doc = to_doc(html_or_doc)

            el = html_or_doc.css(args[1])[0]

            if el.present?
              html_or_doc = html_or_doc.css(args[1])[0]
            else
              raise "Can't find anything by css selector '#{args[1]}'"
            end
          else
            raise "unknown remove type '#{args[0]}': '#{line}'"
          end

        else
          raise "unknown cmd '#{cmd}'"
        end
      else
        raise "failed to parse line ##{index}: #{line}"
      end
    end

    html_or_doc
  end

  def processor_markdown(html_or_doc, options={})
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, {autolink: true, tables: true}.merge(options))
    markdown.render(to_html(html_or_doc))
  end

  def processor_fix_headers(html_or_doc)
    doc = to_doc(html_or_doc)

    ###########################################################################
    # Headers levelize
    max_header_level = nil

    (1..6).each do |level|
      max_header_level = level if doc.css("h#{level}").size > 0
      break unless max_header_level.nil?
    end


    if max_header_level.present?
      range = max_header_level < 2 ? (6).downto(max_header_level) : max_header_level.upto(6)

      range.each do |level|
        doc.css("h#{level}").each do |el|
          new_level = level - (max_header_level - 2)
          el.replace "<h#{new_level}>#{el.inner_html}</h#{new_level}>"
        end
      end
    end

    doc
  end

  def processor_align_images_to_center(html_or_doc)
    doc = to_doc html_or_doc

    doc.css("img").each do |img|
      img["class"] ||= ""
      img["class"] += " img-responsive"
    end

    doc
  end

  def processor_responsive_images(html_or_doc)
    doc = to_doc html_or_doc

    doc.css("img").each do |img|
      img["class"] = ""
      img["class"] += " center-block"
    end

    doc
  end

  def processor_responsive_embded(html_or_doc)
    doc = to_doc html_or_doc

    doc.css("embded,video,iframe,object").each do |el|
      el["class"] = "embed-responsive-item"
      el.replace "<div class=\"embed-responsive embed-responsive-16by9\">#{el.to_html}</div>"
    end

    doc
  end

  def processor_remove_empty_paragraphs(html_or_doc)
    doc = to_doc html_or_doc

    doc.css("p,div").each do |el|
      if el.text.gsub(/[[:space:]]+/, "").blank?
        if el.css("img,iframe,video").size == 0
          el.remove 
        end
      end
    end

    doc
  end

  def processor_fix_paragraphs(html_or_doc)
    doc = to_doc html_or_doc

    doc.css("br").each do |br|
      br.add_next_sibling("\n\n")
      br.remove
    end

    doc.css("p,div").each do |el|
      el.replace "\n\n#{el.inner_html}\n\n"
    end

    paragraphs = to_html(doc).gsub(/\r\n?/, "\n").split(/\n\n+/).map! do |t|
      t.gsub!(/([^\n]\n)(?=[^\n])/, '\1') || t
    end

    html = paragraphs.map! do |html|
      "\n<p>#{html}</p>\n"
    end.join

    processor_remove_empty_paragraphs(html)
  end

  def processor_sanitize(html_or_doc)
    html = to_html html_or_doc

    Sanitize.fragment(html, {
      :elements => %w(h2 h3 h4 h5 h6 p a strong i b blockquote stroke ul li ol em del img cut table tr td th video iframe embded object),
      :add_attributes => {
        'a' => {'rel' => 'nofollow'},
      },
      :attributes => {
        :all => %w(href src alt title name start),
      },
    })
  end

  # TODO: разбить на мелкие методы
  def format_content(html)
    ###########################################################################
    # Nokogiri 1

    doc = Nokogiri::HTML::DocumentFragment.parse(html)

    doc.css("br").each do |br|
      br.add_next_sibling("\n\n")
    end

    doc.css("p,div").each do |el|
      el.replace "\n\n<br /><br />#{el.inner_html}<br /><br />\n\n"
    end

    ###########################################################################
    # Sanitize

    html = sanitize(simple_format(html, {}, sanitize: false), tags: %w(h2 h3 h4 h5 h6 p a strong i b blockquote stroke ul li ol em del img cut table tr td th video iframe embded object), attributes: %w(href src alt title name start))

    ###########################################################################
    # Nokogiri 2

    # Так как все классы порежутся simple_format,
    # поэтому добавляем их после
    doc = Nokogiri::HTML::DocumentFragment.parse(html)


    doc.css("embded,video,iframe,object").each do |el|
      el["class"] = "embed-responsive-item"
      el.replace "<div class=\"embed-responsive embed-responsive-16by9\">#{el.to_html}</div>"
    end

    doc.css("p").each do |el|
      if el.text.remove(/[[:space:]]+/m).blank?
        if el.css("img,iframe,video").size == 0
          el.remove 
        end
      end
    end

    doc.css("p").each do |el|
      el["class"] = "tiny" if el.text.strip.size < 200
    end

    html = doc.to_html

    raw html
  end

  def to_doc(html_or_doc)
    if html_or_doc.respond_to?(:to_html)
      html_or_doc
    else
      Nokogiri::HTML::DocumentFragment.parse(html_or_doc)
    end
  end

  def to_html(html_or_doc)
    if html_or_doc.respond_to?(:to_html)
      html_or_doc.to_html
    else
      html_or_doc
    end
  end
end
