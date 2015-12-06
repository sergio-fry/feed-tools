require 'sinatra/base'
require 'nokogiri'
require 'ostruct'
require 'feedjira'
require 'digest'

require './lib/markup_helpers'

class FeedTools < Sinatra::Base
  include MarkupHelpers


  PROCESSORS = {
    markdown: "Markdown",
    fix_headers: "Fix headers",
    responsive_images: "Responsive images (Bootstrap)",
    align_images_to_center: "Align images to center (Bootstrap)",
    responsive_embded: "Responsive embded, video, iframes (Bootstrap)",
    sanitize: "Sanitize",
    fix_paragraphs: "Fix paragraphs",
    remove_empty_paragraphs: "Remove empty paragraphs",
  }

  get "/" do
    processors = params[:processors] || []

    <<-HTML
<h1>Feedler Builder</h1>

<form action="/feed">
  <p>
    <label for="url">URL</label>
    <br />
    <input type="text" id="url" name="url" value="#{params[:url]}" />
  </p>

  <p>
    <label for="rules">Cleanup Rules</label>
    <br />
    <textarea id="rules" name="rules" cols=80 rows=20>#{params[:rules]}</textarea>
  </p>

  <p>
    <strong>Markup options</strong>

    #{PROCESSORS.map { |key, title| processor_checkbox(key, title) }.join("\n")}
  </p>

  <p>
    <input type="submit" />
  </p>
</form>
    HTML
  end


  get "/feed" do
    feed = Feedjira::Feed.fetch_and_parse(params[:url])

    entries = feed.entries.map do |entry|
      rules = (params[:rules] || "").to_s.split("\n").map(&:strip).compact
      rules += default_cleanup_rules(params[:url])

      content = cleanup_html(entry.content || entry.summary || "", rules)

      (params[:processors] || []).each do |name|
        content = send("processor_#{name}", content)
      end

      url = url_after_redirects entry.url

      struct = OpenStruct.new({
        id: url,
        url: url,
        title: entry.title,
        author: entry.author,
        published: entry.published || Time.at(0),
        content: to_html(content),
      })

      struct.updated = entry.updated || struct.published

      struct
    end


    builder = Nokogiri::XML::Builder.new("encoding" => "UTF-8") do |xml|
      xml.feed "xmlns" => "http://www.w3.org/2005/Atom", "xml:lang" => "en-US" do |xml|
        xml.id Digest::MD5.hexdigest(request.url)

        if entries.size > 0
          xml.updated entries[0].updated.utc.iso8601(0)
        end

        xml.title feed.title, :type => "text"
        xml.link :rel => "self", :href => request.url

        entries.each do |entry|
          xml.entry do
            xml.title entry.title

            unless entry.author.nil?
              xml.author do |xml|
                xml.name entry.author
              end
            end

            xml.link "href" => entry.url
            xml.id entry.url
            xml.published entry.published.utc.iso8601(0)
            xml.updated entry.updated.utc.iso8601(0)
            xml.content entry.content, :type => "html"
          end
        end
      end
    end

    headers "Content-Type" => "text/xml; charset=UTF-8"
    builder.to_xml
  end

  private

  # получаем полный url - после редиректов
  def url_after_redirects(source_url)
    follow_url = lambda { |url| HTTPClient.new.head(url).header['Location'][0] }

    target_url = source_url

    loop do
      next_url = follow_url.call(target_url)

      break if next_url.blank?

      target_url = next_url
    end

    target_url
  rescue
    source_url
  end

  def default_cleanup_rules(feed_url)
    rules = []

    if feed_url.match /ftr.fivefilters.org/
      rules << "remove regexp /This entry passed through the Full-Text RSS service.+/im"
    end

    if feed_url.match /feeds.feedburner.com/
      rules << "remove css .feedflare"
    end

    rules
  end

  def processor_checkbox(key, title)
    processors = params[:processors] || []

    <<-HTML
    <br />
    <input type="checkbox" name="processors[]" id="" value="#{key}" #{processors.include?(key) ? "checked" : "" }/> <label for="#{key}">#{title}</label>
    HTML
  end
end



