require 'nokogiri'

module MarkupHelpers

  def cleanup_html(html, rules=nil)
    # удаляем комментарии
    doc = Nokogiri::HTML::DocumentFragment.parse(html)
    doc.xpath('//comment()').remove
    html = doc.to_html

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

            html = html.gsub regexp, ""
          when "css"
            doc = Nokogiri::HTML::DocumentFragment.parse(html)
            doc.css(args[1]).each(&:remove)

            html = doc.to_html
          else
            raise "unknown remove type '#{args[0]}': '#{line}'"
          end

        when "select"
          case args[0]
          when "css"
            doc = Nokogiri::HTML::DocumentFragment.parse(html)

            el = doc.css(args[1])[0]

            if el.present?
              html = doc.css(args[1])[0].to_html
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

    html
  end

  # TODO: разбить на мелкие методы
  def format_content(html)
    ###########################################################################
    # Mardown
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true)
    html = markdown.render(html)

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
    # Headers levelize
    max_header_level = nil

    (1..6).each do |level|
      max_header_level = level if doc.css("h#{level}").size > 0
      break if max_header_level.present?
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


    html = doc.to_html

    ###########################################################################
    # Sanitize

    html = sanitize(simple_format(html, {}, sanitize: false), tags: %w(h2 h3 h4 h5 h6 p a strong i b blockquote stroke ul li ol em del img cut table tr td th video iframe embded object), attributes: %w(href src alt title name start))

    ###########################################################################
    # Nokogiri 2

    # Так как все классы порежутся simple_format,
    # поэтому добавляем их после
    doc = Nokogiri::HTML::DocumentFragment.parse(html)

    doc.css("img").each do |img|
      img["class"] = "img-responsive center-block"
    end

    doc.css("a").each do |img|
      img["target"] = "_blank"
    end

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
end
