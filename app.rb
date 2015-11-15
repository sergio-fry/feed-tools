require 'sinatra/base'
require 'nokogiri'
require 'ostruct'
require 'feedjira'

class FeedTools < Sinatra::Base
  get "/" do
    <<-HTML
<h1>Feedler Builder</h1>

<form action="/feed">
  <p>
    <label for="title">Title</label>
    <br />
    <input type="text" id="title" name="title" value="#{params[:title]}" />
  </p>
  <p>
    <label for="url">URL</label>
    <br />
    <input type="text" id="url" name="url" value="#{params[:url]}" />
  </p>

  <p>
    <label for="regexp">Replace Regexp</label>
    <br />
    <textarea id="regexp" name="regexp" cols=80 rows=20>#{params[:regexp]}</textarea>
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
      content = entry.content || entry.summary || ""

      url = url_after_redirects entry.url

      OpenStruct.new({
        id: url,
        url: url,
        title: entry.title,
        author: entry.author,
        published: entry.published || Time.at(0),
        updated: entry.updated || entry.published,
        content: content,
      })
    end


    builder = Nokogiri::XML::Builder.new("encoding" => "UTF-8") do |xml|
      xml.feed "xmlns" => "http://www.w3.org/2005/Atom", "xml:lang" => "en-US" do |xml|
        xml.id "urn:citizen428:github:newrepos"
        xml.updated Time.now.utc.iso8601(0)
        xml.title "New GitHub Ruby Repos", :type => "text"
        xml.link :rel => "self", :href => "/ruby_github.atom"

        entries.each do |entry|
          xml.entry do
            xml.title entry.title
            xml.author do |xml|
              xml.name entry.author
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

    headers "Content-Type" => "application/rss+xml"
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
end



