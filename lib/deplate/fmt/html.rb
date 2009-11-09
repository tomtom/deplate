# encoding: ASCII
# fmt-html.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     17-Mär-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.4383

# require 'cgi'
require 'uri'
require 'deplate/compat/parsedate'
require 'time'
require 'pathname'

require 'deplate/formatter'

# A sample html formatter.

class Deplate::Formatter::HTML < Deplate::Formatter
    self.myname = 'html'
    self.rx     = /html?/i
    self.suffix = '.html'

    self.label_delegate = [
        :format_heading,
        :format_LIST,
        :format_anchor,
        :format_list,
        :format_list_env,
    ]

    self.label_once = [
        :format_table,
        :format_IMG,
        :format_figure,
        :format_IDX,
        :format_MAKEBIB,
        :format_paragraph,
        :format_verbatim,
    ]
       
    attr_accessor :html_class

    ################################################ Setup {{{1
    def initialize(deplate, args)
        super
        # Create OpenOffice compatible footnotes
        @footnote_template    = 'sdfootnote%dsym'
        @html_navigation_note = nil
        @is_html_pageicons    = false
        @special_symbols = {
            %{"} => %{&quot;},
            %{>} => %{&gt;},
            %{<} => %{&lt;},
            %{&} => %{&amp;},
            # %{€} => %{&euro;},
            %{ } => lambda {|escaped| escaped ? '&nbsp;' : ' '},
        }
        build_plain_text_rx
        @encodings = {
            'latin1' => 'ISO-8859-1',
        }
        @deplate.output.attributes[:stepwiseIdx] ||= 0
    end

    def hook_post_write_file_html
        return if @deplate.variables['cssInclude']
        @deplate.options.css.each do |name, anyway|
            begin
                src = @deplate.collected_css[name]
                if src
                    css  = File.basename(src)
                    dest = @deplate.auxiliary_filename(css, true)
                    if anyway or !File.exist?(dest)
                        @deplate.copy_file(src, dest)
                    end
                else
                    srcc = @deplate.auxiliary_filename(Deplate::Core.ensure_suffix(name, '.css'), true)
                    unless File.exist?(srcc)
                        log(['File not found', srcc], :error)
                    end
                end
            rescue
                log(["Cannot copy css file", name], :error)
            end
        end
    end
    
    def hook_pre_body_flush_html
        url = @variables['baseUrl']
        if url
            fn = output_destination
            if fn && fn != '-'
                fn  = Pathname.new(fn).expand_path
                unless fn.dirname.to_s == '.'
                    pwd = Pathname.new(Dir.pwd).expand_path
                    fn  = fn.relative_path_from(pwd).to_s.gsub(/\\/, '/')
                    fp  = @variables['baseUrlStripDir']
                    if fp
                        fn = fn.split(/\//)
                        fn = fn[fp.to_i..-1]
                        fn = File.join(*fn)
                    end
                end
                url += fn
                # if @variables["useDublinCore"]
                    set_at(:pre, :head_identifier, head_meta_tag(%{name="DC.Identifier" content="%s"}) % url)
                # else
                # end
            end
        end

        unless @is_html_pageicons
            if @deplate.post_matter[@deplate.slot_by_name(:html_pageicons)]
                consume_label('pageicons', true)
                output_at(:post, :html_pageicons_beg, %{<div id="pageicons" class="pageicons">})
                output_at(:post, :html_pageicons_end, %{</div>})
                @is_html_pageicons = true
            end
        end

        unless output_empty_at?(:body, :footnotes)
            output_at(:body, :footnotes, :prepend, %{<div class="footnotes">})
            output_at(:body, :footnotes, %{</div>})
        end
    end

    def prepare
        html_head

        bodyOpts = @variables['bodyOptions'] || ''
        output_at(:pre,  :body_beg, %{<body #{bodyOpts}>\n<a name="#pagetop"></a>})

        output_at(:post, :body_end, '</body>')
        output_at(:post, :doc_end,  '</html>')

        @deplate.postponed_print << Proc.new do
            ch = close_headings(0)
            output_at(:body, :inner_body_end, ch)
        end
    end

    def html_head
        output_at(:pre, :doc_def,  head_doctype)
        output_at(:pre, :doc_beg,  html_def)
        output_at(:pre, :head_beg, '<head>')

        # t = canonic_encoding('ISO-8859-1')
        t = document_encoding()
        t = %{http-equiv="content-type" content="text/html; charset=#{t}"}
        output_at(:pre, :head, head_meta_tag(t))

        author = @deplate.get_clip('author')
        author = clean_tags(author.elt) if author
        desc   = @variables['description']
        kw     = keywords
        lang   = html_lang(true)

        date   = @deplate.get_clip('date')
        if date
            date = date.elt
            if date =~ /^\d\d(\d\d)$/
                date = Time.local(date)
            elsif !date.empty?
                if date =~ /^(\w+)(\s+|-|\.|\/)(\d\d(\d\d))$/
                    date = "1-#$1-#$3"
                end
                begin
                    date = ParseDate.parsedate(date, true)
                    date = Time.local(*date)
                rescue
                    log(["Cannot parse date", @deplate.get_clip("date").elt], :error)
                    date = nil
                end
            end
        end
        if date == ''
            date = nil
        else
            date ||= Time.now
            # date   = date.xmlschema
            date   = xmlschema(date)
        end
            
        title = @deplate.get_clip('title')
        title = clean_tags(title.elt) if title

        if @variables['useDublinCore']
            output_at(:pre, :head_meta, head_meta_tag(%{name="DC.Title" content="%s"}) % title) if title
            output_at(:pre, :head_meta, head_meta_tag(%{name="DC.Creator" content="%s"}) % author) if author
            # DC.Subject
            output_at(:pre, :head_meta, head_meta_tag(%{name="DC.Description" content="%s"}) % desc) if desc
            # DC.Publisher, DC.Contributor
            output_at(:pre, :head_meta, head_meta_tag(%{name="DC.Date" content="%s"}) % date) if date
            # DC.Type, DC.Format, DC.Identifier, DC.Source
            output_at(:pre, :head_meta, head_meta_tag(%{name="DC.Language" content="%s"}) % lang) if lang
            # DC.Relation, DC.Coverage, DC.Rights
        else
            output_at(:pre, :head_meta, head_meta_tag(%{name="author" content="%s"}) % author) if author
            output_at(:pre, :head_meta, head_meta_tag(%{name="description" content="%s"}) % desc) if desc
            output_at(:pre, :head_meta, head_meta_tag(%{name="keywords" content="%s"}) % kw.join(', ')) if kw
            output_at(:pre, :head_meta, head_meta_tag(%{name="language" content="%s"}) % lang) if lang
            output_at(:pre, :head_meta, head_meta_tag(%{name="date" content="%s"}) % date) if date
        end
        output_at(:pre, :head_meta, head_meta_tag(%{name="generator" content="deplate.rb #{Deplate::Core.version}"})) unless @variables['noGenerator']
        md = @variables['metaDataExtra']
        output_at(:pre, :head_meta, md) if md

        output_at(:pre, :head_title, %{<title>%s</title>} % title) if title
        
        news = @variables['newsFeed']
        if news
            news = [news] if news.kind_of?(String)
            for feed in news
                opts, text = @deplate.input.parse_args(feed, nil, false)
                if (href = opts['rss'])
                    opts['type'] = 'rss'
                elsif (href = opts['atom'])
                    opts['type'] = 'atom'
                else
                    href = opts['href'] || text
                end
                case opts['type']
                when 'atom'
                    type = 'application/atom+xml'
                else
                    type = 'application/rss+xml'
                end
                type  = %{type="#{type}"}
                href  = %{href="#{href}"}
                title = %{title="#{plain_text(opts['title'] || opts['type'])}"}
                output_at(:pre, :head_meta, head_link_tag(['rel="alternate"', type, title, href].join(' ')))
            end
        end

        headExtra = @variables['headExtra']
        headExtra = headExtra.join("\n") if headExtra.kind_of?(Array)
        output_at(:pre, :head_extra, headExtra) if headExtra and !headExtra.empty?
       
        css = head_css
        output_at(:pre, :css, css) unless css.empty?

        styleExtra = @variables['styleExtra']
        if styleExtra
            styleExtra = styleExtra.join("\n") if styleExtra.kind_of?(Array)
            styleExtra = <<EOH
<style type="text/css">
    <!--
    #{styleExtra}
    -->
</style>
EOH
            output_at(:pre, :css, styleExtra) 
        end

        shortcutIcon = @variables["shortcutIcon"]
        if shortcutIcon
            shortcutIcon = escape_filename(shortcutIcon)
            output_at(:pre, :head_end, head_link_tag(%{rel="shortcut icon" href="#{shortcutIcon}" type="image/x-icon"}))
        end
        pageicon = @variables["pageIcon"]
        if pageicon
            pageicon = escape_filename(pageicon)
            output_at(:pre, :head_end, head_link_tag(%{rel="icon" href="#{pageicon}" type="image/x-icon"}))
        end

        output_at(:pre, :html_relations, invoke_service('navigation_links')) unless @variables['noPageNavigation']
       
        output_at(:pre, :head_end, @variables['explorerHack'])
        output_at(:pre, :head_end, '</head>')
    end

    def head_meta_tag(text)
        return %Q{<meta #{text}>}
    end

    def head_link_tag(text)
        return %Q{<link #{text}>}
    end

    def xmlschema(time)
        z = time.zone.scan(/([+-])(\d+):(\d+)/)[0]
        z = z ? ('%s%02d:%02d' % z) : ''
        if time.hour != 0 or time.min != 0 or time.sec != 0
            time.strftime('%Y-%m-%dT%H:%M:%S' + z)
        else
            time.strftime('%Y-%m-%d')
        end
    end
    private :xmlschema

    def read_bib(bibfiles)
        simple_bibtex_reader(bibfiles)
    end
    
    def open_tag(invoker, tag, opts=nil, other_args={})
        args   = invoker.args
        single = other_args[:single] || false
        no_id  = other_args[:no_id] || false
        opts ||= {}
        args ||= {}
        unless no_id
            id  = use_id(args, opts)
            oid = opts['id']
            if oid and oid != id
                invoker.log(['ID mismatch', id, oid, opts, args], :error)
            end
            opts['id'] = encode_id(id) if id
            # args = args.dup
            args.delete('id')
        end
        id = opts['id']
        unless consume_label(id)
            opts = opts.dup
            opts.delete('id')
        end
        cls = opts['class']
        case cls
        when Array
            unless opts['class'].empty?
                opts['class'] = class_attr(opts['class'])
            end
        when nil
            opts['class'] = get_html_class(invoker)
        end
        opts = opts.collect do |k, v|
            if v and !(v.empty?)
                %{%s="%s"} % [k, v]
            end
        end
        if single
            opts << '/'
        end
        %{<%s>} % [tag, *opts].compact.join(' ')
    end
   
    def close_tag(invoker, tag)
        %{</%s>} % tag
    end

    def inline_tag(invoker, tag, text, opts={})
        [open_tag(invoker, tag, opts), text, close_tag(invoker, tag)].join
    end
    
    def wrap_formatted_particle_styles(invoker, value, args)
        s = args[:styles]
        unless !s or s.empty?
            value.sub!(/\A(\s*)(.*?)(\s*)\Z/m) do |m|
                %{#$1<span class="#{class_attr(s)}">#$2</span>#$3}
            end
        end
        value
    end

    def wrap_formatted_element_styles(invoker, value, args)
        s = args[:styles]
        unless !s or s.empty?
            value.sub!(/\A(\s*)(.*?)(\s*)\Z/m) do |m|
                <<EOT
#$1<div class="#{class_attr(s)}">
#$2
</div>#$3
EOT
            end
        end
        value
    end

    def wrap_formatted_element_zz_stepwise(invoker, value, args)
        if @variables['stepwiseDisplay']
            idx = stepwise_next
            beg = (@variables['stepwiseBegin'] || '1').to_i
            vis = idx > beg ? 'hidden' : 'visible'
            value.sub!(/\A(\s*)(.*?)(\s*)\Z/m) do |m|
                <<EOT
#$1<div id="Step#{idx}" style="visibility:#{vis};">
#$2
#$1</div>#$3
EOT
            end
        end
        value
    end

    def wrap_text(text, args={})
        # args[:break_at] ||= '>'
        args[:check] ||= lambda do |line|
            line =~ /<[^>]*$/
        end
        super(text, args)
    end
   
    def class_attr(classes)
        classes.flatten.compact.uniq.join(' ')
    end

    unless defined?(KEYS)
        KEYS = {
            'bs'        => '8', 'backspace'   => '8',
            'tab'       => '9',
            'enter'     => '13', 'cr'         => '13', 'return'     => '13',
            'shift'     => '16',
            'ctrl'      => '17',
            'alt'       => '18', 'meta'       => '18',
            'pause'     => '19',
            'esc'       => '27', 'escape'     => '27',
            'space'     => '32',
            'pageup'    => '33',
            'pagedown'  => '34',
            'left'      => '37',
            'right'     => '39',
            'n'         => '78',
            '-'         => '109', 'dash'      => '109',
            'f1'        => '112',
            'f2'        => '113',
            'f3'        => '114',
            'f4'        => '115',
            'f5'        => '116',
            'f6'        => '117',
            'f7'        => '118',
            'f8'        => '119',
            'f9'        => '120',
            'f10'       => '121',
            'f11'       => '122',
            'f12'       => '123',
            ','         => '188', 'comma'     => '188',
            '.'         => '190', 'period'    => '190',
            '#'         => '191', 'sharp'     => '191',
        }
    end

    def keys_name_to_id(keys)
        Deplate::Core.split_list(keys, ',', '; ').collect {|key| KEYS[key.downcase] || key}.join(',')
    end

    ################################################ Lists {{{1
    def format_list_item(invoker, type, level, item, args={})
        indent = format_indent(level, true)
        body = item.body
        opts = {'class' => ["#{type}-#{level}"]}
        html_class ||= get_html_class(invoker, :add => item.style, :set => false)
        if html_class
            opts['class'] << html_class
        end
        case type
        when 'Ordered', 'Itemize'
            explicit = args[:explicit]
            ev = list_item_explicit_value(item, explicit)
            if ev
                ev = ev.sub(/\.\s*$/, '')
                if ev =~ /^([[:lower:]])$/
                    ev = $1[0]
                    ev = ev.ord if RUBY_VERSION >= '1.9.1'
                    ev -= 96
                elsif ev =~ /^([[:upper:]])$/
                    ev = $1[0] - 64
                    ev = ev.ord if RUBY_VERSION >= '1.9.1'
                    ev -= 64
                end
                opts['value'] = ev.to_s
            else
                case item.item
                when '-'
                    opts['class'] << 'dash'
                when '+'
                    opts['class'] << 'plus'
                when '*'
                    opts['class'] << 'asterisk'
                end
            end
            li = open_tag(invoker, 'li', opts)
            # indent1 = format_indent(level + 1, true)
            # return %{#{indent}#{li}\n#{indent1}#{body}}, %{#{indent}</li>}
            body = indent_text(wrap_text(body), :mult => level + 1)
            return %{#{indent}#{li}\n#{body}}, %{#{indent}</li>}
        when 'Description'
            dt = open_tag(invoker, 'dt', opts)
            dd = open_tag(invoker, 'dd', opts)
            accum = []
            accum << "#{dt}#{item.item}</dt>\n" if item.item
            accum << "#{dd}\n"
            accum << indent_text(wrap_text(body), :mult => 1) if body
            return indent_text(accum.join, :mult => level), "#{indent}</dd>"
        when 'Task'
            pri  = item.opts[:priority]
            cat  = item.opts[:category]
            done = item.opts[:done] ? 'done' : nil
            due  = item.opts[:due]
            opts = {}
            cls  = cat ? [html_class, cat].join('-') : html_class
            opts['class'] = class_attr([cls, done])
            li   = open_tag(invoker, 'li', opts)
            task = [cat, pri].compact.join
            task += " #{due}" if due
            body = [%{<span class="#{cls}">#{task}</span>}, body].join(' ')
            body = indent_text(wrap_text(body), :mult => level + 1)
            return %{#{indent}#{li}\n#{body}}, %{#{indent}</li>}
        when 'Paragraph'
            body = wrap_text(body)
            body = %{<br class="itempara" />#{body}} unless args[:follow_container]
            return indent_text(body, :mult => 2), nil
        when 'Container'
            return body, nil
        else
            invoker.log(['Unknown list type', type], :error)
        end
    end
    
    def format_list_env(invoker, type, level, what, subtype=nil)
        indent = format_indent(level)
        opts   = {'class' => []}
        html_class ||= get_html_class(invoker, :add => type, :set => false)
        if html_class
            opts['class'] << html_class
        end
        case type
        when 'Ordered'
            case subtype
            when 'a'
                opts['type'] = 'a'
                opts['class'] << 'alpha'
            when 'A'
                opts['type'] = 'A'
                opts['class'] << 'Alpha'
            # when "1"
            #     type = %{}
            else
                opts['class'] << 'numeric'
            #     type = %{}
            end
            tag = 'ol'
        when 'Itemize'
            tag = 'ul'
        when 'Task'
            tag = 'ul'
            opts['class'] << 'Task'
        when 'Description'
            tag = 'dl'
        else
            invoker.log(['Unknown list type', type], :error)
        end
        
        case what
        when :open
            return indent + open_tag(invoker, tag, opts)
        when :close
            return indent + close_tag(invoker, tag)
        end
    end


    ################################################ General {{{1
    def format_environment(invoker, env, opts, text)
        if text
            ot = open_tag(invoker, env, opts)
            ct = close_tag(invoker, env)
            join_blocks([ot, text, "#{ct}\n"])
        end
    end

    def get_html_class(invoker, args={})
        if invoker.respond_to?(:html_class)
            html_class = invoker.html_class
        else
            html_class = nil
        end
        unless html_class
            default    = args[:default]
            html_class = [
                invoker.args[:htmlClass],
                invoker.args['htmlClass'],
                invoker.styles_as_string,
                args[:style],
                args[:html_class],
                (args[:add] || []),
            ]
            html_class.flatten!
            html_class.compact!
            if html_class.empty?
                html_class = default
            else
                html_class.uniq!
                html_class = class_attr(html_class)
            end
            if invoker.respond_to?(:html_class=) and args[:set] != false
                invoker.html_class = html_class
            end
        end
        return html_class
    end
    
    def format_label(invoker, mode=nil, label=nil, with_id=true)
        accum   = []
        label ||= invoker.label
        label   = use_labels(invoker.args, label, :with_id => with_id)
        unless !label or label.empty?
            case mode
            when :before
                for l in label
                    accum << %{<a name="#{l}">}
                    @open_labels << l
                end
            when :after
                for l in label
                    if @open_labels.delete(l)
                        accum << '</a>'
                    end
                end
            when :closeOpen
                while !@open_labels.empty?
                    l = @open_labels.pop
                    accum << format_label(invoker, :after)
                end
            # when :once
            else
                for l in label
                    text = if block_given? then yield(l) else '' end
                    accum << %{<a name="#{l}"></a>#{text}}
                end
            end
        end
        return accum.join
    end

    def format_figure(invoker, inline=false, elt=nil)
        elt ||= invoker.elt
        if inline
            include_image(invoker, elt, invoker.args)
        else
            acc = []
            fig     = @deplate.msg('Figure')
            caption = invoker.caption
            if caption
                capAbove = !(caption && caption.args && caption.args.include?("below"))
                lev      = invoker.level_as_string
                # copts    = ["", %{style="text-align=#{float_align_caption(invoker)};"}]
                # cap      = %{<p#{copts.join(" ")} class="caption">#{fig} #{lev}: #{caption.elt}</p>}
                cap      = %{<p class="caption">#{fig} #{lev}: #{caption.elt}</p>}
            else
                capAbove = false
            end
            #+++options: here/top etc.
            acc << %{<div class="figure">}
            if caption and capAbove
                acc << cap
            end
            acc << include_image(invoker, elt, invoker.args)
            if caption and !capAbove
                acc << cap
            end
            acc << "</div>\n"
            join_blocks(acc)
        end
    end

    def include_image_general(invoker, file, args, inline=false)
        acc  = []
       
        file = args['file'] if args['file']
        file = img_url(use_image_filename(file, args))
        acc << %{src="#{file}"}
        
        w = args['w'] || args['width']
        acc << %{width="#{w}"} if w
        h = args['h'] || args['heigth']
        acc << %{height="#{h}"} if h
       
        # b = args['border'] || '0'
        # acc << %{border="#{b}"}
        
        # f = file[0..-(File.extname(file).size + 1)]
        alt = args['alt']
        if alt
            alt.gsub!(/[\\"&<>]/) do |s|
                case s
                when '\\'
                    ''
                else
                    plain_text(s).gsub(/\\([0-9&`'+])/, '\\1')
                end
            end
        else
            alt = File.basename(file, '.*')
        end
        acc << %{alt="#{alt}"}
        
        style = args['style']
        if style
            style = Deplate::Core.split_list(style, ',', '; ', invoker.source)
        else
            style = []
        end
        style << (inline ? 'inline' : 'figure')
        acc << %{class="#{class_attr(style)}"}

        img_id = args['id']
        unless img_id
            fbase  = Deplate::Core.clean_name(File.basename(fbase || 'imgid'))
            img_id = @deplate.auto_numbered(fbase, :inc => 1, :fmt => %{#{fbase}_%s})
        end
        acc << %{id="#{img_id}" name="#{img_id}"}

        hi = args['hi']
        if hi
            case hi
            when String
                hi_img = img_url(use_image_filename(hi, args))
            else
                hi_img = [File.dirname(file), %{hi-#{File.basename(file)}}]
                hi_img = File.join(hi_img.compact)
            end
            
            setup_highlight_image
            acc << %{onMouseover="HighlightImage('%s', '%s')" onMouseout="HighlightImage('%s', '%s')"} % [
                img_id, img_url(hi_img, args), 
                img_id, file
            ]
        end
        
        return %{<img #{acc.join(' ')}/>}
    end

    def setup_highlight_image
        unless @deplate.options.highlight_image
            output_at(:pre, :javascript, <<EOJS
<script type="text/javascript">
<!--
    function HighlightImage(Name, Src) {
        if (document.images) {
            document.images[Name].src = Src
        }
    }
//-->
</script>
EOJS
                     )
            @deplate.options.highlight_image = true
        end
    end

    def img_url(file, args={})
        if args[:raw]
            file
        else
            fmt  = @deplate.variables['htmlImgUrl'] || @deplate.variables['htmlAuxUrl']
            fmt ? fmt % file : file
        end
    end
    
    def image_suffixes
        ['.png', '.jpeg', '.jpg', '.gif', '.bmp', '.wmf']
    end

    ################################################ Elements {{{1
    def format_note(invoker)
        marker = invoker.marker
        case marker
        when '#'
            html_class = 'note'
        when '+'
            html_class = 'warning'
        when '?'
            html_class = 'caution'
        when '!'
            html_class = 'important'
        else
            invoker.log(['Unknown marker', marker], :error)
            html_class = 'note'
        end
        cls = %{ class="%s"} % html_class
        join_blocks(["<div#{cls}><p#{cls}>", invoker.elt, "</p></div>\n"])
    end

    def format_table(invoker)
        args       = invoker.args
        elt        = invoker.elt
        caption    = invoker.caption
        level_as_string   = invoker.level_as_string
        capAbove   = !(caption && caption.args && caption.args.include?('below'))
        style      = invoker.styles_as_string || @variables['tableStyle']
        style.gsub!(/[,;]+/, ' ') if style
        clss       = style || get_html_class(invoker, :default => 'standard')
        clsss      = %{ class="#{clss}"}
        # opts       = format_particle(:table_args, invoker)
        opts       = table_args(invoker)
        halfindent = '  '
        indent     = halfindent * 2
       
        acc = []
        unless args[:dontWrapTable]
            acc << %{<div class="#{class_attr(['table', style])}">}
        end
        acc << %{<table#{clsss}#{opts}>}
        if caption
            if !capAbove
                capOpts = [%{ align="bottom"}]
            else
                # capOpts = [""]
                capOpts = []
            end
            # capOpts << %{style="text-align=#{float_align_caption(invoker)};"}
            cap = %{#{@deplate.msg("Table")} #{level_as_string}: #{caption.elt}}
            acc << %{<caption#{capOpts.join(' ')}>#{cap}</caption>}
        end
      
        acc_head = []
        acc_foot = []
        acc_body = []
        elt.each_with_index do |r, n|
            if r.head
                row = formatted_table_row(n, r, args, indent, clss, 'th')
                if row
                    table_add_row(acc_head, row, %{head #{style}}, :indent => halfindent)
                end
            elsif r.foot
                row = formatted_table_row(n, r, args, indent, clss, 'td')
                if row
                    table_add_row(acc_foot, row, %{foot #{style}}, :indent => halfindent)
                end
            elsif r.high
                row = formatted_table_row(n, r, args, indent, clss, 'td')
                table_add_row(acc_body, row, %{high #{style}}, :indent => halfindent) if row
            elsif r.is_ruler
            else
                row = formatted_table_row(n, r, args, indent, clss)
                table_add_row(acc_body, row, clss, :indent => halfindent) if row
            end
        end

        unless acc_head.empty?
            acc << %{#{halfindent}<thead#{clsss}>}
            acc << acc_head
            acc << "#{halfindent}</thead>"
        end
        unless acc_foot.empty?
            acc << %{#{halfindent}<tfoot#{clsss}>}
            acc << acc_foot
            acc << "#{halfindent}</tfoot>"
        end
        acc << acc_body

        acc << '</table>'
        note = invoker.args['note']
        if note
            note  = @deplate.parse_and_format(invoker, note)
            nopts = ['', %{class="tableNote"}]
            align = float_align_note(invoker)
            nopts << %{style="text-align=#{align};"} if align
            acc   << %{<div#{nopts.join(' ')}>#{note}</div>}
        end
        acc << "</div>\n" unless args[:dontWrapTable]
        acc << ''

        join_blocks(acc)
    end

    # def table_empty_cell
    #     '{ins: &nbsp}'
    # end
    
    def table_add_row(acc, row, clss, args)
        tag       = args[:tag]    || 'tr'
        indent    = args[:indent] || '  '
        dblindent = indent * 2
        row = row.join("\n#{dblindent}")
        acc << %{#{indent}<#{tag} class="#{clss}">}
        acc << %{#{dblindent}#{row}}
        acc << "#{indent}</#{tag}>"
    end

    def format_heading(invoker, level=nil, elt=nil)
        args      = invoker.args
        level   ||= invoker.level
        elt     ||= invoker.elt
        l         = format_label(invoker, nil, nil, false)
        html_args = invoker.html_args || ''
        id        = invoker.get_id
        if consume_label(id)
            html_args += %{ id="#{id}"}
        end
        acc = [close_headings(level), '']
        acc << @variables['htmlHeadingPre']
        acc << @variables["htmlHeadingPre#{level}"]
        if level > 0 and level <= 6
            hd = "h#{level}"
            if invoker.plain_caption?
                ls = ''
            else
                ls  = invoker.level_as_string
                ls += '&nbsp;' if ls
            end
            acc << %{<#{hd}#{html_args}>#{l}#{ls}#{elt}</#{hd}>\n}
        else
            l += format_label(invoker, :string, [id]) if id
            acc << "#{l}#{elt}"
        end
        acc.compact!
        @deplate.options.headings << invoker
        return join_blocks(acc)
    end

    def close_headings(level)
        super(level) do |hlevel|
            post = [@variables["htmlHeadingPost#{hlevel}"], @variables['htmlHeadingPost']].compact
            if post.empty?
                nil
            else
                join_blocks(post)
            end
        end
    end

    def format_list(invoker)
        printable_list(invoker) + "\n"
    end

    def format_break(invoker)
        format_pagebreak(invoker, 'break')
    end

    def format_anchor(invoker)
        format_label(invoker, :once)
    end

    def format_paragraph(invoker)
        # html_class = get_html_class(invoker)
        # cls = html_class.empty? ? "" : (%{ class="%s"} % html_class)
        # join_blocks(["<p#{cls}>", indent_text(invoker.elt, 1), "</p>\n"])
        # [open_tag(invoker, "p"), invoker.elt, close_tag(invoker, "p"), "\n"].join
        [open_tag(invoker, "p"), wrap_text(invoker.elt), close_tag(invoker, "p"), "\n"].join
    end


    ################################################ Regions {{{1
    def format_verbatim(invoker, text=nil)
        text ||= invoker.elt
        format_environment(invoker, 'pre', {'class'=>'verbatim'}, plain_text(text, :pre))
    end

    def format_abstract(invoker)
        format_environment(invoker, %{blockquote}, {'class'=>'abstract'}, invoker.elt)
    end

    def format_quote(invoker)
        elt = invoker.elt.strip
        rv  = [if invoker.args['long']
                  format_environment(invoker, %{blockquote}, {'class'=>'longquote'}, elt)
              else
                  format_environment(invoker, %{blockquote}, {'class'=>'quote'}, elt)
              end]
        if (src = invoker.args['source'])
            rv << format_environment(invoker, %{div}, {'class' => 'source'},
                                     plain_text(src))
        end
        join_blocks(rv)
    end

    def format_header(invoker)
        format_header_or_footer(invoker, :pre, :header, 'HEADER', 'header')
        nil
    end

    def format_footer(invoker)
        format_header_or_footer(invoker, :post, :footer, 'FOOTER', 'footer')
        nil
    end

    
    ################################################ Commands {{{1
    def format_title(invoker)
        acc = []
        acc << @variables['htmlTitlePre']
        acc << %{<div class="title">}
        for i, c in [["title",      %{<#{@variables['htmlTagTitle'] || 'p class="title"'}>%s</p>}],
                     ["author",     %{<#{@variables['htmlTagAuthor'] || 'p class="author"'}>%s</p>}], 
                     ["authornote", %{<#{@variables['htmlTagAuthorNote'] || 'p class="authornote"'}>%s</p>}],
                     ["date",       %{<#{@variables['htmlTagDate'] || 'p class="date"'}>%s</p>}]]
            ii = @deplate.get_clip(i)
            acc << c % ii.elt if ii
        end
        acc << %{</div>}
        acc << @variables['htmlTitlePost']
        acc << format_pagebreak(invoker, 'title') if invoker.args['page']
        join_blocks(acc.compact)
    end

    alias :format_IMG :format_figure

    alias :format_MAKETITLE :format_title

    def format_MAKEBIB(invoker)
        format_bibliography(invoker) do |key, labels, text|
            consume_label(key, true)
            %{<p id="#{key}" class="bib">#{labels}#{text}</p>}
        end
    end

    def format_IDX(invoker)
        invoker.elt
    end

    def format_pagebreak(invoker, html_class=nil, major=false)
        if html_class
            opt = %{ class="#{html_class}"}
        else
            opt = %{ class="pagebreak"}
        end
        # poor man's pagebreak
        "<hr#{opt} />\n"
    end


    ################################################ Particles {{{1
    def format_emphasize(invoker, text=nil)
        text ||= invoker.elt || invoker.text
        inline_tag(invoker, 'em', text)
    end
    
    def format_code(invoker, text=nil)
        text ||= invoker.elt || invoker.text
        inline_tag(invoker, 'code', plain_text(text, :code))
    end
    
    def format_url(invoker, name, dest, anchor, literal=false)
        dest = Deplate::HyperLink.url_anchor(dest, anchor)
        dest.gsub!(/&/, '&amp;')
        if name =~ /^mailto:(.*)$/
            name = $1
        end
        inline_tag(invoker, 'a', name, href_args(invoker, dest))
    end

    def format_wiki(invoker, name, dest, anchor)
        dest = Deplate::HyperLink.url_anchor(dest, anchor)
        # dest.gsub!(/&/, "&amp;")
        inline_tag(invoker, 'a', name, href_args(invoker, dest))
    end
   
    def href_args(invoker, dest)
        args = {'href' => dest}
        target = invoker.args['target']
        if target
            args['target'] = target
        end
        rel = invoker.args['rel']
        if rel
            args['rel'] = rel
        end
        return args
    end
    private :href_args
    
    def format_symbol(invoker, text)
        case text
        when '<-'
            return '&larr;'
        when '->'
            return '&rarr;'
        when '<=', '<<<'
            return '&lArr;'
        when '=>', '>>>'
            return '&rArr;'
        when '<->'
            return '&harr;'
        when '<=>'
            return '&hArr;'
        when '!='
            return '&ne;'
        when '~~'
            return '&asymp;'
        when '...'
            return '&hellip;'
        when '--'
            return '&ndash;'
        when '=='
            return '&equiv;'
        when '+++', '###', '???', '!!!'
            m = plain_text(text)
            return %{<span class="marker"><em class="marker">#{m}</em></span>}
            # when "<~"
            # return ""
            # when "~>"
            # return ""
            # when "<~>"
            # return ""
        else
            return plain_text(text)
        end
    end

    def doublequote_open(invoker)
        '&ldquo;'
    end
    
    def doublequote_close(invoker)
        '&rdquo;'
    end
    
    def singlequote_open(invoker)
        '&lsquo;'
    end
    
    def singlequote_close(invoker)
        '&rsquo;'
    end

    
    ################################################ Macros {{{1
    def format_index(invoker, idx)
        if idx
            return format_label(invoker, :string, [idx.label])
        else
            return ''
        end
    end

    def format_footnote(invoker)
        elt = invoker.elt
        if elt and elt.elt and elt.fn_consumed
            lab = elt.fn_label
            if !@deplate.footnotes_used.include?(lab)
                idx      = @deplate.footnote_last_idx +=1
                hclass   = 'sdfootnoteanc'
                id       = 'sdfootnote%d'    % idx
                name     = 'sdfootnote%danc' % idx
                href     = @footnote_template % idx
                lab      = [href]
                elt.fn_n  = idx
                elt.fn_label = lab
                @deplate.footnotes_used << lab
                invoker.container.postponed_format << Proc.new do |container|
                    consume_label(id, true)
                    t = [
                        %{<div id="#{id}">},
                    ]
                    l = %{<a class="sdfootnotesym" name="#{href}" href="##{name}">#{idx}</a>}
                    e = elt.elt[0]
                    case e
                    when Deplate::Element::Paragraph
                        e.elt.insert(0, l)
                    else
                        t << l
                    end
                    elt.push_styles('sdfootnote')
                    t << elt.format_current
                    t << %{</div>}
                    output_at(:body, :footnotes, t.join("\n"))
                end
            else
                href = @footnote_template % elt.fn_n
            end
            return %{<a class="sdfootnoteanc" name="#{name}" href="##{href}">#{elt.fn_n}</a>}
        else
            return ''
        end
    end

    def format_ref(invoker)
        text = invoker.text || ''
        f = @deplate.get_filename_for_label(invoker, text)
        if f
            # if invoker.args['obj'] and (o = @deplate.label_aliases[text])
            o = @deplate.label_aliases[text]
            if o
                l = o.level_as_string
            else
                l = @deplate.labels[text]
            end
            if l
                t = plain_text(l)
            else
                t = @variables['refButton'] || '[&rArr;]'
            end
            prefix = invoker.args['prefix'] || '&nbsp;'
            return %{#{prefix}<a href="#{URI.escape(f)}##{URI.escape(text)}" class="ref">#{t}</a>}
        else
            return text.empty? ? '??' : text
        end
    end

    def format_linebreak(invoker)
        open_tag(invoker, 'br', nil, :single => true)
    end

    def referenced_bib_entry(invoker, key, text)
        hd = @deplate.options.html_makebib_heading
        f  = hd ? hd.top_heading.output_file_name(:relative => invoker.container) : ''
        %{<a href="#{f}##{encode_id(key)}">#{text}</a>}
    end
    
    def format_subscript(invoker)
        inline_tag(invoker, 'sub', invoker.elt)
    end

    def format_superscript(invoker)
        inline_tag(invoker, 'sup', invoker.elt)
    end

    # this doesn't work with IExplorer and others
    def format_stacked(invoker)
        elt = invoker.elt
        sup = %{<span style="display:table-row"><sup style="display:table-cell">#{elt[0]}</sup></span>}
        sub = %{<span style="display:table-row"><sub style="display:table-cell">#{elt[1]}</sub></span>}
        stk = %{<span style="font-size: 80%; position:relative; top:0.5em; display:inline-table">#{sup}#{sub}</span>}
        return stk
    end

    def format_pagenumber(invoker)
        return ''
    end


    protected ######################################## private methods {{{1
    ################################################ General {{{1
    def format_header_or_footer(invoker, type, slot, html_type, html_class)
        args = invoker.args
        acc  = []
        acc << %{<div type="#{html_type}" class="#{html_class}">}
        for e in invoker.elt
            e.html_class = html_class
            e.args[:dontWrapTable] = true
            acc << e.format_current
        end
        acc << %{</div>}
        output_at(type, slot, *acc)
        nil
    end


    ################################################ Head {{{1
    def head_css
        csso = @variables['css']
        if csso
            csss = Deplate::Core.split_list(csso, ',', ' ;', nil, nil)
        else
            csss = []
        end
        cls = @variables['class']
        csss << cls if cls
        acc = []
        if @deplate.variables['cssInclude']
            acc << %{<style type="text/css">} << %{<!--}
        end
        csss.each_with_index do | f, i |
            css, media = f.split(/\|/, 2)
            css = Deplate::Core.ensure_suffix(css, '.css')
            if css =~ /^\+/
                css = css[1..-1]
                with_title = false
            else
                with_title = true
            end
            cssName = File.basename(css, '.css')
            unless @deplate.options.css.find {|c, anyway| cssName == c}
                @deplate.options.css << [cssName]
            end
            if @deplate.variables['cssInclude']
                cssFile = @deplate.collected_css[cssName]
                if cssFile and File.readable?(cssFile)
                    acc << File.read(cssFile)
                else
                    log(['File not found', 'Cannot include CSS', css], :error)
                end
            else
                cssFile = @deplate.auxiliary_filename(css)
                cssFmt  = @deplate.variables['htmlCssUrl'] || @deplate.variables['htmlAuxUrl']
                cssFile = cssFmt % cssFile if cssFmt
                opts = [%{rel="stylesheet" type="text/css" href="#{URI.escape(cssFile)}"}]
                opts << %{title="#{cssName}"} if with_title
                opts << %{media="#{media}"}  if media
                acc << head_link_tag(opts.join(' '))
            end
        end
        cssExtra = @variables['cssExtra']
        acc << cssExtra if cssExtra
        if @deplate.variables['cssInclude']
            acc << %{-->} << %{</style>}
        end
        return acc.join("\n")
    end

    def head_doctype
        return %Q{<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">}
    end
    
    def html_lang(stripped=false)
        lang = @deplate.options.messages.prop('lang', self)
        if lang
            return stripped ? lang : %{lang="#{lang}"}
        end
    end

    def html_def
        acc = []
        acc << html_lang
        acc << @variables['htmlDefEtc'] if @variables['htmlDefEtc']
        if acc.empty?
            return '<html>'
        else
            return "<html #{acc.join(' ')}>"
        end
    end

    
    ################################################ List of ... {{{1
    def format_list_of_toc(invoker)
        format_list_of(invoker, 
                       :title => 'Table of Contents',
                       :prefix => 'hd', 
                       :listing => 'toc', 
                       :flat => false, 
                       :style => 'toc')
    end

    def format_list_of_minitoc(invoker)
        data = @deplate.options.listings.get('toc').find_all {|e| e.level == 1}
        format_list_of(invoker, 
                       :title => 'Contents', 
                       :prefix => 'hd', 
                       :data => data, :flat => false, 
                       :img => @variables['navGif'],
                       :style => 'minitoc') do |hd|
            hd.args['shortcaption'] || hd.args['id']
        end
    end

    def format_list_of_lot(invoker)
        format_list_of(invoker, 
                       :title => 'List of Tables', 
                       :prefix => 'tab', 
                       :listing => 'lot',
                       :flat => true,
                       :style => 'lot')
    end

    def format_list_of_lof(invoker)
        # @html_class = "lof"
        format_list_of(invoker, 
                       :title => 'List of Figures', 
                       :prefix => 'fig', 
                       :listing => 'lof', 
                       :flat => true, 
                       :style => 'lof')
    end

    def format_list_of_index(invoker)
        format_the_index(invoker, 'Index', 
                         @deplate.index, 
                         'idx', 
                         true, 
                         :style => 'index')
    end

    def listing_prematter(invoker, args, id)
        img = args[:img]
        img = %{<img src="#{img_url(img, args)}" border="0" alt="" />} if img
        %{<div id="%s">%s\n<div id="%sBlock" class="%s">} % [
            id,
            img,
            id,
            get_html_class(invoker, args)
        ]
    end
    
    def listing_postmatter(invoker, args)
        %{</div></div>}
    end
    
    def listing_title(invoker, args, name)
        if name
            %{<h1 class="%s">%s%s</h1>} % [
                get_html_class(invoker, args), 
                format_label(invoker), 
                @deplate.msg(name)
            ]
        end
    end
    
    def listing_item(invoker, args, prefix, title, heading, level, other_args)
        v = clean_tags(title)
        v = [heading.level_as_string, v].join(' ') unless heading.plain_caption?
        f = heading.output_file_name(:relative => invoker)
        d = [f, @deplate.elt_label(prefix, heading.level_as_string)].join('#')
        b = format_url(invoker, v, d, nil, true)
        s = Deplate::ListItem.new(nil, b, 'Itemize', 'Itemize', level, 0, true)
        s.style = get_html_class(invoker, args)
        s
    end
    
    def format_the_index(invoker, name, data, prefix='', flat=false, other_args={})
        style  = other_args[:style] || 'index'
        accum  = []
        chars  = []
        
        # accum << format_list_env(invoker, "Description", 0, :open)
        for n, arr in sort_index_entries(data)
            cht = get_first_char(n, true)
            if !chars.include?(cht)
                chars << cht
                lab = format_label(invoker, :string, [format_index_hd_label(cht)])
                accum << format_list_env(invoker, "Description", 0, :close) unless accum.empty?
                accum << %{<h2 class="%s">%s%s</h2>} % [style, lab, cht]
                accum << format_list_env(invoker, "Description", 0, :open)
            end
            acc = []
            for i in arr
                ff = @deplate.dest
                xf = i.file(invoker)
                xc = i.container
                xl = xc && xc.heading_level
                if xf or xl
                    begin
                        f = xf || invoker.output_file_name(:level_as_string => xl, 
                                                           :relative => invoker)
                        if f == ff
                            f = ''
                            l = xl
                            if l and !l.empty?
                                t = l
                            elsif @deplate.options.multi_file_output
                                t = @variables['refButton'] || '[&rArr;]'
                            else
                                t = 'I'
                            end
                        else
                            t = @deplate.file_with_suffix(f, '', true)
                        end
                        acc << format_url(invoker, t, f, i.label, true)
                    rescue Exception => e
                        invoker.log(['Internal error: No output file', n, i.label, ff, xf, xl, invoker.class, e], :error)
                    end
                else
                    invoker.log(['Index: Neither file nor level defined: dropping', n, i.label], :error)
                end
            end
            l = format_label(invoker, :string, [format_index_entry_label(invoker, n)])
            s = Deplate::ListItem.new(l + plain_text(n), acc.join(', '))
            accum += format_list_item(invoker, 'Description', 0, s)
        end
        accum << format_list_env(invoker, 'Description', 0, :close)

        acc = []
        acc << %{<p class="%stoc">} % style
        for c in chars
            l = format_url(invoker, c, "", format_index_hd_label(c), true)
            acc << l
        end
        acc << %{</p>}
        acc << accum.join("\n")
        join_blocks(acc)
    end
    
    def format_index_entry_label(invoker, text)
        return "idxEntry00" + text.gsub(/\W/, "00")
    end

    def format_index_hd_label(char)
        return "hdIdx#{Deplate::Core.clean_name(char, :chars => '^a-zA-Z0-9')}"
    end
   

    ################################################ Table {{{1
    def table_args(invoker)
        args    = invoker.args
        caption = invoker.caption
        opts    = [nil]
        align   = float_align(invoker)
        case align
        when 'center'
        when 'right'
        when 'left'
        end
        opts << %{align="#{align}"} if align
        width = args['width'] || @variables['tableWidth']
        opts << %{width="#{width}"} if width
        opts << %{summary="#{clean_tags(caption.elt)}"} if caption and caption.elt
        return opts.join(' ')
    end

    def float_align(invoker)
        args = invoker.args
        args['align'] || @variables['floatAlign']
        # || 'center'
    end

    def float_align_caption(invoker)
        float_align(invoker)
        # || "left"
    end
    
    def float_align_note(invoker)
        float_align(invoker)
        # || "left"
    end
    
    def formatted_table_row(n, row, args, indent, html_class=nil, thistag=nil)
        colwidths = Deplate::Core.props(args['cols'], 'w')
        coljusts  = Deplate::Core.props(args['cols'], 'j')
        rowheight = Deplate::Core.props(args['rows'], 'h')
        t = []
        row.cols.each_with_index do |cell, i|
            case cell
            when :join_left, :join_above
            when :ruler, :noruler
                return nil
            else
                if cell.class == Array
                    puts caller[0..10].join("\n")
                    log(["We shouldn't be here. If you can track down when this happens, please send an example to the author.", cell[0].get_text], :error)
                    return []
                else
                    c = cell.cell
                end
                if thistag
                    tag = thistag
                else
                    if row.head
                        tag = 'th'
                    else
                        tag = 'td'
                    end
                end

                opts = []
                opts << if row.head
                            %{ class="head #{html_class}"}
                        elsif row.foot
                            %{ class="foot #{html_class}"}
                        elsif cell.high or row.high
                            %{ class="high #{html_class}"}
                        else
                            %{ class="#{html_class}"}
                        end

                styles = []
                w = colwidths[i]
                if w and !w.empty?
                    styles << %{width:%s} % w
                end
                j = coljusts[i]
                if j and !j.empty?
                    styles << %{text-align:%s} % j
                end
                h = rowheight[n]
                if h and !h.empty?
                    styles << %{height:%s} % h
                end

                if styles.empty?
                    styles = ""
                else
                    opts << %{style="%s"} % styles.join('; ')
                end

                if cell.span_x > 1
                    opts << %{colspan="#{cell.span_x}"}
                end
                if cell.span_y > 1
                    opts << %{rowspan="#{cell.span_y}"}
                end

                # t << "<#{tag}#{opts.join(" ")}>#{indented(c, indent)}\n#{indent}</#{tag}>"
                t << "<#{tag}#{opts.join(' ')}>#{c}</#{tag}>"
            end
        end
        t
    end
    
    def indented(text, indent)
        return text.collect do |l|
            indent + l
        end
    end


    public
    ################################################ navigation bar {{{1
    def format_navigation_bar(invoker, type, slot, bartype, first=nil, last=nil)
        idx, first, last = navbar_output_index(invoker, first, last)

        nomenu    = invoker.args['noNavMenu'] || @variables['noNavMenu']
        nobuttons = invoker.args['noNavButtons'] || @variables['noNavButtons']
        
        navbar_begin(type, slot, idx)
        navbar_menu(type, slot, idx, bartype) unless nomenu
        unless nobuttons
            urlp, prv = navbar_button_prev(type, slot, idx, bartype, !first && idx > 0)
            url, home = navbar_button_home(type, slot, idx, bartype, idx > 0)
            urln, nxt = navbar_button_next(type, slot, idx, bartype, !last)

            case bartype
            when :top, :inline
                if urlp
                    titp      = @deplate.options.heading_names[idx - 1]
                    link_prev = head_link_tag(%{rel="previous" href="#{urlp}" title="#{clean_tags(titp)}"})
                    set_at(:pre, :htmlsite_prev,  link_prev)
                end
                if urln
                    titn      = @deplate.options.heading_names[idx + 1]
                    link_next = head_link_tag(%{rel="next" href="#{urln}" title="#{clean_tags(titn)}"})
                    set_at(:pre, :htmlsite_next, link_next)
                    urlspace = urln
                else
                    urlspace = url
                end
                if url
                    tit       = @deplate.options.heading_names[0]
                    link_up   = head_link_tag(%{rel="up" href="#{url}" title="#{clean_tags(tit)}"})
                    set_at(:pre, :htmlsite_up, link_up)
                end
                unless bartype == :inline or @variables['noBindKeys']
                    output_at(:body, :navbar_js, invoke_service('navigation_keys', 'next' => urlspace))
                end
            else
                if (first or idx == 0) and !@variables['noNavigationNote']
                    output_at(type, slot, invoke_service('navigation_note'))
                end
            end
        end
        navbar_end(type, slot, idx)
    end

    def format_navigation_buttons(invoker, type, slot, bartype, first=false, last=false)
        idx, first, last = navbar_output_index(invoker, first, last)
        urlp, prv = navbar_button_prev(type, slot, idx, bartype, !first && idx > 0)
        url, home = navbar_button_home(type, slot, idx, bartype, idx > 0)
        urln, nxt = navbar_button_next(type, slot, idx, bartype, !last)
        output_at(type, slot, [urlp, url, urln].join)
    end
    
    def navbar_button_prev(type, slot, idx, bartype, ok)
        if ok
            text = @variables['prevButton'] || plain_text('<<')
            urlp = navbar_guess_file_name(idx - 1, idx, bartype)
            ak   = bartype == :top ? %{ accesskey="B"} : ''
            prv  = %{<a class="navbarUrl" title="Previous" href="#{urlp}"#{ak}>#{text}</a>}
        else
            urlp = nil
        end
        unless urlp
            prv  = '&nbsp;'
        end
        navbar_add_element(type, slot, idx, prv, 'navbar')
        return urlp, prv
    end
    
    def navbar_button_home(type, slot, idx, bartype, ok)
        if ok or @variables['homeShowAlways']
            text = @variables['homeButton'] || '[-]'
            url  = navbar_guess_file_name(@deplate.home_index, idx, bartype) || '#pagetop'
            ak   = [:top, 'navbar'].include?(bartype) ? %{ accesskey='H'} : ''
            hc   = ['navbar'].include?(bartype) ? 'navBar' : 'navbarUrl'
            home = %{<a class="#{hc}" title="Home" href="#{url}"#{ak}>#{text}</a>}
        else
            url  = nil
        end
        unless url
            home = '&nbsp;'
        end
        navbar_add_element(type, slot, idx, home, 'navbar')
        return url, home
    end

    def navbar_button_next(type, slot, idx, bartype, ok)
        if ok
            text = @variables['nextButton'] || plain_text('>>')
            urln = navbar_guess_file_name(idx + 1, idx, bartype)
            ak   = bartype == :top ? %{ accesskey='N'} : ''
            nxt  = %{<a class="navbarUrl" title="Next" href="#{urln}"#{ak}>#{text}</a>}
        else
            urln = nil
        end
        unless urln
            nxt  = '&nbsp;'
        end
        navbar_add_element(type, slot, idx, nxt, 'navbar')
        return urln, nxt
    end
    
    def navbar_menu(type, slot, idx, bartype)
        # unless @deplate.options.navmenu
            navmenu = [%{<form action=""><select class="navmenu" name="Contents"
              onChange="self.location.href=this.form.Contents.options[this.form.Contents.options.selectedIndex].value">}, 
              %{<option value="">[ #{@deplate.msg("Contents")} ]</option>},
              %{<option value="">------------------------</option>}]
   
            acc = []
            @variables['@contents'] ||= acc
            th = @deplate.output.top_heading
            @deplate.each_heading(:top) do |hd, title|
                file = hd.output_file_name(:basename => true)
                unless hd.kind_of?(Deplate::NullTop)
                    anchor = hd.get_id
                    if anchor
                        file += "##{anchor}"
                    end
                    acc << [title, file]
                end
                pre = (hd.level and hd.level > 1) ? ('&nbsp;' * hd.level) : nil
                o = []
                o << 'selected' if hd == th
                if o.empty?
                    o = nil
                else
                    o << nil unless o.empty?
                    o = o.join(' ')
                end
                navmenu << %{<option #{o}value="#{file}">#{pre}#{title}</option>}
            end

            navmenu << %{</select>}
            # navmenu << %{<button class="navgo" name="Go" type="button" value="Go" onClick="self.location.href=this.form.Contents.options[this.form.Contents.options.selectedIndex].value">}
            # navmenu << %{<p class="navgo">%s</p>} % (@variables["goButton"] || "Go")
            # navmenu << %{</button>}
            navmenu << %{</form>}
            @deplate.options.navmenu = navmenu.join("\n")
        # end
        navbar_add_element(type, slot, idx, @deplate.options.navmenu, 'navmenu')
    end
    
    
    ################################################ Site navigation {{{1
    def format_navigation_links(depth)
        acc = []
        start = navbar_guess_file_name(0, nil, :inline)
        if start and start != ''
            fp_title = @deplate.msg('Frontpage')
            acc << head_link_tag(%{rel="start" href="#{start}" title="#{clean_tags(fp_title)}"})
        end
        tags = ['', 'chapter', 'section', 'subsection']
        @deplate.each_heading(depth || @deplate.options.split_level) do |hd, hd_title|
            ref    = tags[hd.level]
            anchor = hd.args[:id] || hd.label.first
            file   = hd.output_file_name(:basename => true)
            file   = escape_filename(file)
            file   = [file, '#', anchor].join if anchor
            acc << head_link_tag(%{rel="#{ref}" href="#{file}" title="#{clean_tags(hd_title)}"})
        end
        acc.join("\n")
    end
   
    def escape_filename(fname)
        fname.split(/\//).collect {|p| URI.escape(p)}.join('/')
    end
    
    def navbar_guess_file_name(idx, base=nil, bartype=nil, section=nil)
        b  = @deplate.output_filename_by_idx(base)
        ff = @deplate.output_filename_by_idx(idx)
        f  = @deplate.relative_path_by_file(ff, b)
        f  = escape_filename(f)
        if bartype == :inline
            section ||= @deplate.top_heading_by_idx(idx)
            if section
                anchor = section.args[:id] || section.label.first
                if anchor and anchor != 'deplateNullTop'
                    f = [f, '#', anchor].join
                end
            end
        end
        return f
    end

    def handle_key(keys, function)
        keys = ',%s,' % keys_name_to_id(keys)
        @deplate.output.attributes[:handle_keys] ||= {}
        @deplate.output.attributes[:handle_keys][keys] = function
    end

    def_service('navigation_links') do |args, text|
        depth = args['depth']
        depth &&= depth.to_i
        format_navigation_links(depth)
    end

    def_service('navigation_bar') do |args, text|
        type = :array
        slot = []
        invoker = args[:invoker]
        if invoker
            invoker.args.update(args)
        else
            invoker = Deplate::PseudoContainer.new(@deplate, :args => args)
        end
        bartype = if args['top']
                      :top
                  elsif args['bottom']
                      :bottom
                  else
                      :inline
                  end
        format_navigation_bar(invoker, type, slot, bartype)
        slot.join("\n")
    end

    # 8  ... BS
    # 9  ... tab
    # 13 ... enter
    # 16 ... shift
    # 17 ... ctrl
    # 18 ... alt
    # 19 ... pause
    # 27 ... esc
    # 32 ... space
    # 33 ... page up
    # 34 ... page down
    # 37 ... left
    # 39 ... right
    # 78 ... n
    # 109 ... -
    # 112 ... F1
    # ..
    # 121 ... F10
    # 188 ... ,
    # 190 ... .
    # 191 ... #
    def_service('navigation_keys') do |args, text|
        urln = args['next']
        if urln
            last = false
        else
            idx, first, last = navbar_output_index(args[:invoker])
            urln = navbar_guess_file_name(idx + 1, idx)
        end
        # prevKey = @variables['prevKey'] || '8'
        acc = []
        if urln and !last
            nextKey = @variables['nextKey'] || '16'
            handle_key(nextKey, 'NavigationNextPage();') if nextKey.to_i > 0
            acc << <<EOJS
<script type="text/javascript">
    <!--
        function NavigationNextPage() {
            window.location="#{urln}";
        }
    //-->
</script>
EOJS
        end
        acc.join
    end
   
    def_service('navigation_handle_keys') do |args, text|
        keys = @deplate.output.attributes[:handle_keys]
        if keys
            acc = [<<EOJS
<script type="text/javascript">
    <!--
        function HandleKeys() {
            this.event = function(e) {
                if (!e) { e = window.event; }
EOJS
            ]
            cmd = nil
            keys.each do |key, fn|
                cmd = cmd ? '} else if' : 'if'
                acc << <<EOJS
                #{cmd} ("#{key}".indexOf(","+ e.keyCode +",") != -1) {
                    #{fn}
EOJS
            end
            #     } else {
            #         alert('DBG key code='+ e.keyCode);
            acc << <<EOJS
                }
            };
            var self = this;
        }
        var k = new HandleKeys();
        document.onkeydown = k.event;
    //-->
</script>
EOJS
            acc.join
        else
            ''
        end
    end
    
    def_service('stepwise_display') do |args, text|
        stepKey = @variables['stepwiseKey'] || '34'
        # if @variables['stepwiseDisplay'] and stepKey
        if stepKey
            handle_key(stepKey, 'StepwiseDisplayNext();')
            stepInit = @variables['stepwiseBegin'] || '0'
            unless defined?(@nextPage)
                catch(:exit) do
                    # files = ['StepWiseNextPage.js']
                    style = args['style'] || @variables['stepwiseStyle']
                    files = [style ? "StepWiseNextPage_#{style}.js" : 'StepWiseNextPage.js']
                    for file in files
                        @nextPage = get_javascript(file, args)
                        throw :exit if @nextPage
                    end
                    @nextPage = ''
#                 <<EOJS
# function StepwiseNextPage(Msg) {
#     return confirm(Msg);
# }
# EOJS
                end
            end
            acc = []
            acc << <<EOJS
#{@nextPage}
<script type="text/javascript">
    <!--
        var StepwiseCounter = #{stepInit};

        function StepwiseDisplayNext() {
            StepwiseCounter = StepwiseCounter + 1;
            var Elt = document.getElementById('Step' + StepwiseCounter);
            var HighStep = document.getElementById('HighStep' + StepwiseCounter);
            var NextHighStep = document.getElementById('HighStep' + (StepwiseCounter + 1));
            if (Elt)
                Elt.style.visibility = 'visible';
            else if (HighStep)
                if (NextHighStep)
                    HighStep.className = 'stephighlight';
                else
                    HighStep.className = 'steplast';
EOJS
            case @variables['stepwiseContinous']
            when 'confirm', 'query', 'ask', 'yn'
                acc << <<EOJS
            else
                if (StepwiseNextPage("#{@deplate.msg('Next page?')}"))
                    NavigationNextPage();
EOJS
            when true, 1, '1'
                acc << <<EOJS
            else
                NavigationNextPage();
EOJS
            end
            acc << <<EOJS
        }
    //-->
</script>
EOJS
            acc.join
        else
            ''
        end
    end

    def_service('navigation_buttons') do |args, text|
        type = :array
        slot = []
        invoker = args[:invoker]
        if invoker
            invoker.args.update(args)
        else
            invoker = Deplate::PseudoContainer.new(self, :args => args)
        end
        format_navigation_buttons(invoker, type, slot, :inline)
        slot.join("\n")
    end

    def_service('navigation_note') do |args, text|
        unless @html_navigation_note
            @html_navigation_note   = @deplate.msg(:htmlnavigation_note)
            unless @html_navigation_note
                @html_navigation_note = [
                    %{<p class="htmlnavigationnote" />},
                    %{<hr class="htmlnavigationnote" />},
                    %{<p class="htmlnavigationnote">Navigation tips:</p>},
                    %{<ul class="htmlnavigationnote">},
                    %{<li class="htmlnavigationnote"> Press &lt;a-n&gt; to jump to the next page</li>},
                    if args['nextKey'] then
                    %{<li class="htmlnavigationnote"> Press &lt;#{args['nextKey']}&gt; to jump to the next page</li>}
                    end,
                        %{<li class="htmlnavigationnote"> Press &lt;a-b&gt; to jump to the previous one</li>},
                        %{<li class="htmlnavigationnote"> Press &lt;a-h&gt; to jump to the title page</li>},
                        %{<li class="htmlnavigationnote"> It depends on the browser whether 
                these shortcuts are activated (e.g. Mozilla) or just selected (e.g. MS IE), 
                in which case you have to press &lt;enter&gt;</li>},
                %{</ul>},
                ].join("\n")
            end
        end
        @html_navigation_note
    end

    def get_javascript(file, args)
        file = @deplate.find_in_lib(file, :formatters => ['javascript'])
        if file
            tmpl = Deplate::Template.new(:template  => File.read(file))
            Deplate::Define.let_variables(@deplate, args) do
                return tmpl.fill_in(@deplate).join("\n")
            end
        else
            log(['File not found', file])
        end
        return nil
    end


    private
    def navbar_begin(type, slot, idx)
        output_at(type, slot, %{<table class="navbar"><tr class="navbar">})
    end
    
    def navbar_end(type, slot, idx)
        output_at(type, slot, %{</tr></table>})
    end
    
    def navbar_add_element(type, slot, idx, element, htmlclass)
        if !@variables['noTabBarButtons'] and type and slot
            output_at(type, slot, %{<td class="#{htmlclass}">#{element}</td>})
        end
    end

    # Return [idx, first, last]
    def navbar_output_index(invoker, first=nil, last=nil)
        acc = []
        if invoker.respond_to?(:top_heading) and !invoker.kind_of?(Deplate::PseudoContainer)
            th = invoker.top_heading
        else
            th  = @deplate.output.top_heading
        end
        if th
            idx = @deplate.output_index(th)
        end
        acc << idx
        gf = th.first_top
        gl = th.last_top
        # else
        #     out = @deplate.output
        #     acc << idx
        #     gf = (idx == @deplate.home_index)
        #     gl = (idx == @deplate.top_heading_idx)
        # end
        case first
        when true, false
            acc << first
        else
            acc << gf
        end
        case last
        when true, false
            acc << last
        else
            acc << gl
        end
        return acc
    end

end


class Deplate::Base
    attr_accessor :html_class, :html_args

    def hook_pre_setup_html
        @html_class = nil
        @html_args  = nil
    end
end


class Deplate::Command::MAKEBIB
    accumulate_pre(self, Deplate::Formatter::HTML) do |src, array, deplate, text, match, args, cmd|
        unless args['plain']
            n = Deplate::Element::Heading.markup(deplate.msg('Bibliography'))
            m = Deplate::Element::Heading.match(n)
            Deplate::Element::Heading.accumulate(src, array, deplate, n, m)
            o = array[-1]
            o.finish.update_options(args)
            deplate.options.html_makebib_heading = o
        end
    end
end


class Deplate::Command::LIST
    accumulate_pre(self, Deplate::Formatter::HTML) do |src, array, deplate, text, match, args, cmd|
        if text == 'index' and !args['plain'] and !args['noTitle']
            n = Deplate::Element::Heading.markup(deplate.msg('Index'))
            m = Deplate::Element::Heading.match(n)
            Deplate::Element::Heading.accumulate(src, array, deplate, n, m)
            o = array[-1]
            o.finish.update_options(args)
        end
    end
end

