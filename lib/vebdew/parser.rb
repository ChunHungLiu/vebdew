module Vebdew
  class Parser
    attr_reader :header, :body, :footer

    def initialize lines
      @lines = lines
      @header = []
      @body = []
      @footer = []
      @buffer = []
      @attrs = ""
      @flag = Hash.new { |h, k| h[k] = false }

      parse
    end

  protected
    def parse
      for raw_line in @lines
        line = raw_line.lstrip

        # special case for no enders
        close_flag :ul if @flag[:ul] and !line.match(/^\* (.+)/)

        case line
        when /^:(\w+) (.*)$/
          command $1, $2
        when /^\!SLIDE/
          close_buffer
          close_flag :slide
          start_flag :slide
        when /^\!ENDSLIDE/
          close_buffer
          close_flag :slide
        when /^\!STACK/
          close_buffer
          close_flag :slide
          close_flag :stack
          start_flag :stack
        when /^\!ENDSTACK/
          close_buffer
          close_flag :slide
          close_flag :stack
        when /\{:([^\}]+)\}/
          selector $1
        when /^~+/
          if @flag[:code]
            @body << @buffer.join
            @buffer.clear
            close_flag :code
          else
            close_buffer
            start_flag :code
          end
        when /^(#+) (.*)/
          level = $1.size
          @body << "<h#{level}#{append}>#{$2}</h#{level}>"
        when /^-+/
          tagged = @buffer.pop
          close_buffer
          if tagged and !tagged.empty?
            @body << "<h2#{append}>#{tagged.strip}</h2>"
          else
            @body << "<hr#{append}>"
          end
        when /^=+/
          tagged = @buffer.pop
          close_buffer
          if tagged and !tagged.empty?
            @body << "<h1#{append}>#{tagged.strip}</h1>"
          end
        when /^\* (.+)/
          start_flag :ul unless @flag[:ul]
          @body << "<li#{append}>#{format_content($1)}</li>"
        else
          @buffer << raw_line
        end
      end
      close_buffer
      close_flag :slide
      close_flag :stack
    end

    def command type, body
      case type
      when "title"
        @header << %Q{<title>#{body}</title>}
      when "description"
        @header << %Q{<meta name="description" content="#{body}">}
      when "author"
        @header << %Q{<meta name="author" content="#{body}">}
      when "email"
        @header << %Q{<meta name="email" content="#{body}">}
      when "stylesheet_link_tag"
        body.split(',').each do |href|
          @header << %Q{<link rel="stylesheet" href="#{href.strip}">}
        end
      when "javascript_include_tag"
        body.split(',').each do |href|
          @footer << %Q{<script type="text/javascript" src="#{href.strip}"></script>}
        end
      else
        # TODO: something wrong!
      end
    end

    def close_buffer
      return if @buffer.empty?
      format_buffer
      @body += @buffer
      @buffer.clear
    end

    START_STR = { :slide => "<section>",
                  :stack => "<section>",
                  :code => "<script type='text/x-sample'>",
                  :ul => "<ul>" }

    def start_flag flag
      str = START_STR[flag]
      str[-1] = "#{append}>" unless @attrs.empty?
      @body << str
      @flag[flag] = true
    end

    CLOSE_STR = { :slide => "</section>",
                  :stack => "</section>",
                  :code => "</script>",
                  :ul => "</ul>" }

    def close_flag flag
      @body << CLOSE_STR[flag] if @flag[flag]
      @flag[flag] = false
    end

    def selector str
      klass = str.scan(/\.([^\.\[#]+)/).flatten
      id = str.scan(/#([^\.\[#])+/).flatten
      attrs = str.scan(/\[([^\.\]=#]+)=([^\.\]]+)\]/)

      @attrs = ""
      @attrs += " class='#{klass.join(' ')}'" unless klass.empty?
      @attrs += " id='#{id.join(' ')}'" unless id.empty?
      attrs.each do |a|
        @attrs += " #{a[0]}='#{a[1]}'"
      end
    end

    def append
      str = @attrs
      @attrs = ""
      str
    end

    def escape_html str
      str.gsub(/>/, "&gt;").gsub(/</, "&lt;")
    end

    def format_buffer
      @buffer.map! do |buf|
        "<p#{append}>#{format_content(buf)}</p>"
      end
    end

    def format_content str
      str.strip!
      str.gsub!(/`(([^\\`]|\\.)*)`/) {%Q{<code>#{escape_html($1)}</code>}}
      str.gsub! /\!\[([^\]]+)\]\(([^\)]+)\)/, %q{<img src='\1' alt='\2'>}
      str.gsub! /\!\[([^\]]+)\]/, %q{<img src='\1'>}
      str.gsub! /\[([^\]]+)\]\(([^\)]+)\)/, %q{<a href='\1'>\2</a>}
      str
    end
  end
end
