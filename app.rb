require 'sinatra/base'
require 'nokogiri'
require 'ostruct'

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

    entries = [
      OpenStruct.new(title: "Title", author: "Author", url: "http://example.com/page", id: "123", published: Time.now, updated: Time.now, content: "Content!"),
    ]


    builder = Nokogiri::XML::Builder.new do |xml|
      xml.root "xmlns" => "http://www.w3.org/2005/Atom" do |xml|
        xml.id "urn:citizen428:github:newrepos"
        xml.updated Time.now.utc.iso8601(0)
        xml.title "New GitHub Ruby Repos", :type => "text"
        xml.link :rel => "self", :href => "/ruby_github.atom"

        entries.each do |entry|
          xml.entry do
            xml.title entry.title
            xml.author entry.author
            xml.link "href" => entry.url
            xml.id entry.url
            xml.published entry.published.utc.iso8601(0)
            xml.updated entry.updated.utc.iso8601(0)
            xml.content entry.content, :type => "html"
          end
        end
      end
    end

    builder.to_xml
  end
end



