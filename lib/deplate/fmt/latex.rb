# encoding: ASCII
# latex.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     17-Mär-2004.
# @Last Change: 2010-10-04.
# @Revision:    0.2213

require "deplate/formatter"

# A sample LaTeX formatter.

class Deplate::Formatter::LaTeX < Deplate::Formatter
    self.myname = "latex"
    self.rx     = /(la)?tex/i
    self.suffix = ".tex"

    self.label_mode = :after
    
    self.label_delegate = [
        :format_heading,
        :format_LIST,
        :format_table,
        :format_inlatex,
        :format_IMG,
        :format_list,
        :format_list_env,
    ]

    self.label_once = [
        :format_anchor,
    ]

    class_attribute :latexDocClass, 'article'
    class_attribute :latexVariables, ['11pt', 'a4paper']


    ################################################ Setup {{{1
    def initialize(deplate, args)
        super
        @special_symbols = {
            "\\" => "\\textbackslash{}",
            ">"  => "$>$",
            "<"  => "$<$",
            "|"  => "$|$",
            "^"  => "\\^{}",
            "~"  => "\\~{}",
            "\"" => "``",
            "["  => "{[}",
            "]"  => "{]}",
            "$"  => "\\$",
            "&"  => "\\&",
            "%"  => "\\%",
            "#"  => "\\#",
            "_"  => "\\_",
            "{"  => "\\{",
            "}"  => "\\}",
            " "  => Proc.new do |escaped|
                        escaped ? "~" : " "
                    end,
        }
        @encodings = {
            'utf-8' => 'utf8',
        }
        @packages  = {}
        @consumed_preludes = []
        build_plain_text_rx
        ignore_styles
    end

    def prepare
        @document_class = @deplate.variables['class'] || self.class.latexDocClass
        ignore_styles

        lco = @deplate.variables['classOptions']
        lco = lco ? Deplate::Core.split_list(lco.strip, ',', '; ') : self.class.latexVariables
        lang = @deplate.options.messages.prop('lang', self)
        # p "DBG", lang
        if lang
            lco << lang
        end

        div = @deplate.variables['DIV'] || @deplate.variables['typeareaDIV']
        if div
            add_package("typearea", "DIV#{div}")
        else
            div = @deplate.variables['DIV_'] || @deplate.variables['typeareaDIV_']
            if div
                add_package('typearea')
                lco.unshift("DIV#{div}")
            end
        end

        lco = lco.uniq.join(',')
        output_at(:pre, :doc_def, "\\documentclass[#{lco}]{#{@document_class}}")
        if @deplate.options.pdftex
            pdfcompresslevel = (@deplate.variables['pdfCompressLevel'] || 9).to_i
            output_at(:pre, :doc_def, "\\pdfcompresslevel#{pdfcompresslevel}")
        end

        set_document_encoding
        
        @booktabs = @deplate.variables['useBooktabs']
        add_package('booktabs') if @booktabs

        lang_cmd = @deplate.options.messages.prop('lang_cmd', self)
        if lang_cmd
            output_at(:pre, :doc_beg, lang_cmd)
        end

        output_at(:pre, :body_beg, "\\begin{document}\n")

        lspread = @deplate.variables["linespread"]
        if lspread
            output_at(:pre, :body_beg, "\\linespread{#{lspread}}")
        end

        output_at(:post, :body_end, "\\end{document}")
    end

    def ignore_styles
        @ignored_styles ||= []
        @ignored_styles += Deplate::Core.split_list(@deplate.variables['ignoredStyles']).map {|s| Regexp.new(s)}
    end

    def prepare_headings
        as_book = case @document_class
                  when 'book', 'memoir', 'scrbook', 'report', 'scrreprt'
                      true
                  else
                      bc = @deplate.variables['bookClass']
                      bc == true || Deplate::Core.split_list(bc).include?(@document_class)
                  end
        if as_book
            @headings = ['chapter', 'section', 'subsection', 'subsubsection', 'paragraph', 'subparagraph']
        else
            @headings = ['section', 'subsection', 'subsubsection', 'paragraph', 'subparagraph']
        end
    end

    def initialize_deplate_sty
        unless @deplate.variables[:deplate_sty]
            add_package('color')
            # add_package('ulem')
            add_package('deplate')
            pkg  = 'deplate.sty'
            dir  = File.dirname(output_destination)
            dest = File.join(dir, pkg)
            unless File.exist?(dest)
                fn = @deplate.find_in_lib(pkg, :pwd => true)
                if fn
                    Deplate::Template.copy(@deplate, fn, dest)
                else
                    log(['Library file not found', pkg], :error)
                end
            end
            @deplate.variables[:deplate_sty] = true
        end
    end

    def wrap_formatted_particle_styles(invoker, value, args)
        s = args[:styles]
        unless s.empty?
            initialize_deplate_sty
            # if preferred_style_markup(invoker, 'particle', 'span')
                value = wrap_inject(value, s,
                                    :spre => '\\%sSpan{',
                                    :post => '}') do |s, pre, post|
                                        ltx = '%s}' % pre.strip
                                        @deplate.endmessage(ltx, %{You might need to define #{ltx} in deplate.sty.})
                                    end
            # else
            #     value = wrap_accumulate(value, args[:styles]) do |s, ltx|
            #         ltx = ltx.strip
            #         @deplate.endmessage(ltx, %{You might need to define #{ltx} in deplate.sty.})
            #     end
            # end
        end
        value
    end

    def wrap_formatted_element_styles(invoker, value, args)
        s = args[:styles]
        unless s.empty?
            initialize_deplate_sty
            # if preferred_style_markup(invoker, 'element', 'block')
                value = wrap_inject(value, s,
                                    :spre => "\\begin{%sBlock}\n",
                                    :spost => "\\end{%sBlock}\n") do |s, pre, post|
                    ltx = '%sBlock' % s.strip
                    @deplate.endmessage(ltx, %{You might need to define the #{ltx} environment in deplate.sty.})
                                    end
            # else
            #     value = wrap_accumulate(value, args[:styles]) do |s, ltx|
            #         ltx = ltx.strip
            #         @deplate.endmessage(ltx, %{You might need to define #{ltx} in deplate.sty.})
            #     end
            # end
        end
        value
    end
    
    # def preferred_style_markup(invoker, what, style)
    #     what = "#{what}Style"
    #     (invoker.args[what] || @deplate.variables[what]) == style
    # end
    # private :preferred_style_markup
    
    def wrap_inject(text, styles, args={})
        styles.inject(text) do |v, s|
            if @ignored_styles.any? {|i| s =~ i}
                v
            else
                s   = clean_style_name(s)
                pfx = args[:pre]
                unless pfx
                    pfx = args[:spre] % s
                end
                sfx = args[:post]
                unless sfx
                    sfx = args[:spost] % s
                end
                if block_given?
                    yield(s, pfx, sfx)
                end
                [pfx, v, sfx].join
            end
        end
    end
    private :wrap_inject

    def clean_style_name(style)
        style.gsub(/\W(.)/) {|t| $1.capitalize}
    end

    def wrap_accumulate(text, styles, template='\\%sStyle{}')
        styles = styles.collect do |s|
            l = template % clean_style_name(s)
            if block_given?
                yield(s, l)
            end
            l
        end
        text.sub(/\A(\s*)(.*?)(\s*)\Z/m) do |m|
            %{#$1{#{styles}#$2}#$3}
        end
    end
    private :wrap_accumulate
    
    def wrap_text(text, args={})
        args[:check] ||= lambda do |line|
            mt = /\\verb(.)/.match(line)
            mt && line =~ /\\verb#{mt[1]}[^#{mt[1]}]+$/
        end
        super(text, args)
    end
    
    def prelude(name)
        case name
        when 'ltxPrelude', 'mathPrelude'
            if @consumed_preludes.include?(name)
                return nil
            else
                @consumed_preludes << name
            end
        end
        return @deplate.variables[name]
    end
    
    def inlatex(invoker)
        pkgs, body   = inlatex_split(invoker.accum)
        invoker.elt  = body.join("\n")
        inlatex_add_packages(pkgs)
    end

    def inlatex_add_packages(pkgs)
        for p in pkgs
            m   = /^\s*\\(usepackage|input)\s*(\[(.*)\])?\s*\{(.+)\}\s*$/.match(p)
            if m
                pkg = m[4]
                if m[3]
                    add_package(pkg, m[3].split(/,/))
                else
                    add_package(pkg)
                end
            else
                output_at(:pre, :user_head, p)
            end
        end
    end
    

    ################################################ Lists {{{1
    def format_list_item(invoker, type, level, item, args={})
        indent = format_indent(level, true)
        ctag   = list_wide? ? '' : :empty
        explv  = list_item_explicit_value(item)
        hang   = 4
        if explv
            explv = %{[#{explv}]}
        end
        case type
        when "Ordered"
            return wrap_text("#{indent}\\item#{explv} #{item.body}", :hanging => hang), ctag
        when "Itemize"
            return wrap_text("#{indent}\\item #{item.body}", :hanging => hang), ctag
        when "Description"
            return wrap_text("#{indent}\\item[#{item.item}] #{item.body}", :hanging => hang), ctag
        when 'Custom'
            t = item.opts[:custom]
            return wrap_text("#{indent}\\#{t}Item{#{item.item}}{#{item.body}}", :hanging => hang), ctag
        when 'Task'
            pri  = item.opts[:priority]
            cat  = item.opts[:category]
            due  = item.opts[:due]
            due  = " (#{due})" if due
            if cat
                task = plain_text([cat, pri, due].join)
                lab  = "\\task#{cat}{#{task}}"
            else
                lab  = plain_text([pri, due].join)
            end
            body = item.body
            if item.opts[:done]
                lab  = "\\taskdone{#{lab}}"
                body = "\\taskdone{#{body}}"
            end
            it   = "#{indent}\\task{#{lab}}{#{body}}"
            return wrap_text(it, :hanging => hang), nil
        when "Paragraph"
            fs = list_wide? ? "\n%s\n" : "\n%s"
            # return fs % wrap_text("#{indent}#{item.body}", :indent => "  "), nil
            return fs % wrap_text("#{indent}#{item.body}"), nil
        when 'Container'
            fs = list_wide? ? "\n%s\n" : "\n%s"
            return fs % item.body, nil
        else
            invoker.log(['Unknown list type', type], :error)
        end
    end
    
    def format_list_env(invoker, type, level, what, subtype=nil)
        indent = format_indent(level)
        case what
        when :open
            w    = "begin"
            if list_wide?
                pre  = "\n#{indent}"
                post = "\n"
            else
                pre  = indent
                post = ""
            end
        when :close
            w    = "end"
            pre  = indent
            post = ""
        end
        case type
        when "Ordered"
            case subtype
            when "a", "A"
                return format_list_enumerate_alpha(invoker, what, subtype, w, pre, post)
            else
                return "#{pre}\\#{w}{enumerate}#{post}"
            end
        when "Itemize"
            return "#{pre}\\#{w}{itemize}#{post}"
        when 'Task'
            initialize_deplate_sty
            return "#{pre}\\#{w}{tasklist}#{post}"
        when 'Custom'
            initialize_deplate_sty
            return "#{pre}\\#{w}{#{subtype}List}#{post}"
        when "Description"
            return "#{pre}\\#{w}{description}#{post}"
        else
            invoker.log(['Unknown list type', type], :error)
        end
    end

    
    ################################################ General {{{1
    def format_environment(invoker, env, text, opts=nil)
        join_blocks(["\\begin{#{env}}", text.rstrip, "\\end{#{env}}#{block_postfix(invoker)}"])
    end

    def format_label(invoker, mode=nil, label=nil)
        acc   = []
        label = use_labels(invoker.args, label || invoker.label, :with_id => true)
        unless label.empty?
            case mode
            when :before
            # when :after, :once
                # for l in label
                    # acc << "\\label{#{l}}"
                # end
            else
                for l in label
                    l = clean_label(l)
                    acc << "\\label{#{l}}"
                end
            end
        end
        return acc.join
    end

    def clean_label(label)
        label.gsub(/[^a-zA-Z_]/, '_')
    end

    def format_figure(invoker, inline=false, elt=nil)
        elt   ||= invoker.elt
        args    = invoker.args
        caption = invoker.caption
        acc = []
        if inline
            acc << include_image(invoker, elt, args, true)
        else
            floatPos, alignCmd = float_options(invoker)
            in_env   = !(args["inline"] || @deplate.variables["imgInline"])
            in_env &&= floatPos || alignCmd || caption
            if in_env
                acc << figure_top(invoker)
                acc << include_image(invoker, elt, args)
                acc << figure_bottom(invoker)
            else
                acc << include_image(invoker, elt, args)
                acc << format_label(invoker, :once)
            end
        end
        join_blocks(acc)
    end

    def figure_top(invoker)
        caption = invoker.caption
        capAbove = caption && (caption.args && caption.args.include?("above") || @deplate.variables["floatCaptionAbove"])
        floatPos, alignCmd = float_options(invoker)
        acc = []
        acc << "\\begin{figure}%s" % [floatPos]
        acc << alignCmd
        if caption and capAbove
            acc << "\\caption{#{caption.elt}}"
        end
        join_blocks(acc)
    end
    
    def figure_bottom(invoker)
        caption = invoker.caption
        capAbove = caption && (caption.args && caption.args.include?("above") || @deplate.variables["floatCaptionAbove"])
        acc = []
        if caption and !capAbove
            acc << "\\caption{#{caption.elt}}"
        end
        acc << format_label(invoker, :once)
        acc << "\\end{figure}#{block_postfix(invoker)}"
        join_blocks(acc)
    end
    
    def include_image_general(invoker, file, args, inline=false)
        if args[:verbatim]
            rv = args[:verbatim]
        else
            file = args['file'] if args['file']
            if file =~ Deplate::HyperLink::Url.rx
                Deplate::Core.log([%{Cannot include remote images in current document}, file], :error)
                file = File.basename(file)
            end
            ff = use_image_filename(file, args)
            o  = []
            bw, bh, bx, by, desc = nil
            @deplate.in_working_dir do
                bw = args['bw']
                bh = args['bh']
                desc = Deplate::External.image_dimension(ff)
                unless (bw and bh) or @deplate.options.pdftex
                    bw, bh, bx, by = desc[:bw]
                end
            end
            unless @deplate.options.pdftex
                o << "bb=0 0 #{bw || "100"} #{bh || "100"}"
            end
            width = args['w'] || args['width']
            if width
                if width =~ /^\d+%$/
                    width = width.to_f / 100
                    o << "width=#{width}\\textwidth{}"
                elsif width =~ /^[.\d]+(cm|mm|in|em|pt)$/
                    o << "width=#{width}"
                else
                    o << "width=#{width}pt"
                end
            elsif !inline
                bb  = desc[:bw]
                bw  = bb ? bb[0] : nil
                res = desc[:res]
                if desc and bb and res
                    estimated_width = bw.to_f / res
                    if estimated_width > 6
                        o << "width=\\textwidth{}"
                    end
                end
            end
            height = args['h']
            if height
                if height =~ /^\d+%$/
                    height = height.to_f / 100
                    o << "height=#{height}\\textheight{}"
                elsif height =~ /^\d+(cm|mm|in|em|pt)$/
                    o << "height=#{height}"
                else
                    o << "height=#{height}pt"
                end
            end
            o = o.join(',')
            if !o.empty?
                o = "[#{o}]"
            end
            add_package('graphicx')
            rv  = "\\includegraphics#{o}{#{ff}}"
            rot = args['rotate'] || @deplate.variables['imgRotate']
            if rot
                rv = %{\\rotatebox{#{rot}}{#{rv}}}
            end
        end
        return rv
    end

    def image_suffixes
        if @deplate.options.pdftex
            ['.pdf', '.jpeg', '.jpg', '.png', '.gif', '.bmp']
        else
            ['.eps', '.ps', '.jpeg', '.jpg', '.png', '.gif', '.bmp']
        end
    end
    
    def add_package(pkg, *options)
        pkg_previous = @packages[pkg]
        if pkg_previous
            if options != pkg_previous
                log(['Already required package with different options', pkg, pkg_previous, options], :error)
            end
            return
        else
            @packages[pkg] = options.dup
            case pkg
            when 'hyperref'
                options << 'pdftex'  if @deplate.options.pdftex
                options << 'unicode' if canonic_encoding() == 'utf-8'
            when 'graphicx'
                options << 'pdftex'  if @deplate.options.pdftex
            end
            
            unless options.empty?
                options = "[#{options.join(',')}]"
            end
            if pkg =~ /\.\w+$/
                output_at(:pre, :user_packages, "\\input{#{pkg}}")
            else
                output_at(:pre, :user_packages, "\\usepackage#{options}{#{pkg}}")
            end
        end
    end

    def include_package?(pkg)
        @packages.include?(pkg)
    end


    ################################################ Elements {{{1
    def format_note(invoker)
        initialize_deplate_sty
        elt    = invoker.elt
        marker = invoker.marker
        case marker
        when '#'
            note = 'Note'
        when '+'
            note = 'Elaborate'
        when '?'
            note = 'Discussion'
        when '!'
            note = 'Important'
        else
            invoker.log(['Unknown marker', marker], :error)
            note = 'Note'
        end
        head = @deplate.msg(note)
        size = @deplate.variables["note#{note}Size"] || @deplate.variables['noteSize'] || 'footnotesize'
        wrap_text('\\note%s{\\%s{}}{%s}{%s}' % [note, size, head, elt])
    end

    def format_table(invoker)
        args      = invoker.args
        elt       = invoker.elt
        caption   = invoker.caption
        capAbove  = caption && (caption.args && caption.args.include?('above') || @deplate.variables['floatCaptionAbove'])
        indent    = format_indent(1)
        dblindent = format_indent(2)
        mode      = :normal
        rown      = elt.size - 1
        invoker.printed_header = false
        acc = []
        acc << with_agent(:table_top, String, invoker, capAbove, rown)
        elt.each_with_index do |row, rnth|
            if row.is_ruler
                t = with_agent(:table_horizontal_ruler, String, invoker, row, rnth)
            elsif row.head
                acc << with_agent(:table_begin_head, String, invoker, rown)
                t = with_agent(:table_head_row, Array, invoker, row, rnth)
                mode = :head
            elsif row.foot
                case mode
                when :foot
                else
                    acc << with_agent(:table_end_body, String, invoker, rown)
                    acc << with_agent(:table_begin_foot, String, invoker, rown)
                end
                t = with_agent(:table_foot_row, Array, invoker, row, rnth)
                mode = :foot
            elsif row.high
                t = with_agent(:table_high_row, Array, invoker, row, rnth)
                mode = :high
            else
                case mode
                when :head
                    acc << with_agent(:table_end_head, String, invoker, rown)
                    acc << with_agent(:table_begin_body, String, invoker, rown)
                else
                end
                mode = :body
                t = with_agent(:table_normal_row, Array, invoker, row, rnth)
            end
            if t
                t = table_join_cells(t)
                acc << with_agent(:table_indented_row, String, invoker, row, dblindent, t)
            end
        end
        if mode == :foot
            acc << with_agent(:table_end_foot, String, invoker, rown)
        end
        acc << with_agent(:table_bottom, String, invoker, capAbove, rown)
        join_blocks(acc)
    end

    def format_heading(invoker, level=nil, elt=nil, args=nil)
        args  ||= invoker.args
        level ||= invoker.level
        elt   ||= invoker.elt
        if invoker
            invoker.label << args[:id]
            labels = format_label(invoker, :string)
        else
            labels  = nil
        end
        hd = @headings[level - 1]
        if hd
            cap = heading_caption(invoker)
            mod = heading_mod(invoker)
            join_blocks(["\n\\#{hd}#{mod}#{cap}{#{elt}}", labels])
        else
            "\n#{elt}#{labels}: "
        end
    end

    def heading_mod(invoker)
        if invoker
            args = invoker.args
            invoker.plain_caption? || args["noList"] || args["plain"] ? "*" : ""
        else
            ''
        end
    end

    def heading_caption(invoker)
        caption = invoker && invoker.caption
        if caption
            return "[#{caption.elt}]"
        else
            return ""
        end
    end

    def format_list(invoker)
        add_package("hyperref")
        acc = list_wide? ? [""] : []
        lab = format_label(invoker)
        unless lab.empty?
            acc << lab
        end
        acc << printable_list(invoker)
        acc << "" unless invoker.inlay?
        join_blocks(acc)
    end

    def format_break(invoker)
        format_pagebreak(invoker, "break")
    end

    def format_anchor(invoker)
    end

    def format_paragraph(invoker)
        rv = wrap_text(invoker.elt)
        if invoker.args[:minor] or invoker.inlay?
            return rv
        else
            return join_blocks([rv, ""])
        end
    end


    ################################################ Regions {{{1
    def format_verbatim(invoker, text=nil)
        format_environment(invoker, "verbatim", text || invoker.elt)
    end

    def format_abstract(invoker)
        format_environment(invoker, "abstract", invoker.elt)
    end

    def format_quote(invoker)
        env = invoker.args["long"] ? "quotation" : "quote"
        # +++TBD CHECK: Extra newlines in output.
        # https://sourceforge.net/forum/message.php?msg_id=5041702
        # elt = wrap_text(invoker.elt)
        elt = invoker.elt
        format_environment(invoker, env, elt)
    end

    def format_header(invoker)
        args = invoker.args
        elt  = invoker.elt
        acc  = []
        acc << %{\\pagestyle{myheadings}}
        catch :error do
            if elt.size == 1
                e = elt[0]
                if e.kind_of?(Deplate::Element::Paragraph)
                    header = e.format_current
                elsif e.kind_of?(Deplate::Element::Table)
                    if e.elt.size > 1
                        invoker.log("Only the header's first row will be used", :error)
                    end
                    header = e.elt[0].cols.collect{|c| c.cell}
                    while header.last.empty?
                        header.pop
                    end
                    header = header.compact.join(" -- ")
                else
                    throw :error
                end
                header.gsub!(/\n+/, " ")
                acc << %{\\markright{#{header}}}
                return join_blocks(acc)
            end
        end
        elts = "%s %s" % [elt.size, elt.collect {|e| e.class}.join(", ")]
        invoker.log(["Header must contain only 1 element (a paragraph or a table)", elts], :error)
    end

    def format_footer(invoker)
        invoker.log("Footer ignored", :error)
    end

    def format_inlatex(invoker)
        args = invoker.args
        elt  = invoker.elt
        acc  = []
        if args["inline"]
            acc << elt
        elsif args["type"] == "table"
            cap      = invoker.caption
            capAbove = cap && cap.args && cap.args.include?("above")
            acc << with_agent(:table_top, String, invoker, capAbove, nil)
            acc << elt
            acc << with_agent(:table_bottom, String, invoker, capAbove, nil)
        elsif args["type"] == "fig"
            acc << with_agent(:figure_top, String, invoker)
            acc << elt
            acc << with_agent(:figure_bottom, String, invoker)
        else
            acc << elt
        end
        join_blocks(acc)
    end


    ################################################ Commands {{{1
    def format_title(invoker)
        acc  = []
        elts = []
        # if @args["page"]
            # +++
        # else
            for i, c in [ ["title",  "\\title{%s}"],
                          ["author", "\\author{%s}"], 
                          ["date",   "\\date{%s}"]
                        ]
                ii = @deplate.get_clip(i)
                if ii
                    elts << i
                    elt = ii.elt
                    case i
                    when "author"
                        an   = @deplate.get_clip("authornote")
                        elt += %{\\protect\\footnote{#{an.elt}}} if an
                    end
                    acc << c % elt
                end
            end
            acc << "\\maketitle\n" if elts.include?("title")
            # and elts.include?("author")
            kw = keywords
            acc << %{#{@deplate.msg("Keywords:")} #{kw.join(", ")}} if kw
            acc << "" unless invoker.inlay?
        # end
        join_blocks(acc)
    end

    alias :format_IMG :format_figure

    alias :format_MAKETITLE :format_title

    def format_MAKEBIB(invoker)
        style = invoker.elt
        if style.empty?
            style = @deplate.variables['bibStyle']
        end
        bib   = @deplate.options.bib.collect{|f| File.basename(f, ".bib")}.join(",")
        "\\bibliographystyle{#{style}}\n\\bibliography{#{bib}}\n"
    end
    alias :format_bibliography :format_MAKEBIB

    def format_IDX(invoker)
        invoker.elt
    end

    def format_pagebreak(invoker, style=nil, major=false)
        "\\clearpage{}"
    end


    ################################################ Particles {{{1
    def format_emphasize(invoker, text=nil)
        text ||= invoker.elt || invoker.text
        "\\emph{%s}" % text
    end
    
    def format_code(invoker, text=nil)
        text ||= invoker.elt || invoker.text
        "\\texttt{%s}" % plain_text(text, true)
    end
    
    def format_url(invoker, name, dest, anchor, literal=false)
        add_package("hyperref")
        # if @deplate.options.pdftex and dest =~ /^~/
            # dest = "file://" + File.expand_path(dest)
        # end
        dest = Deplate::HyperLink.url_anchor(dest, anchor)
        # dest.gsub!(/([&%#])/, "\\\\\\1")
        dest.gsub!(/([%#])/, "\\\\\\1")
        "\\href{%s}{%s}" % [dest, name]
    end

    def format_wiki(invoker, name, dest, anchor)
        add_package("hyperref")
        if dest and !dest.empty?
            invoker.log(["Wiki name as url", dest], :debug)
            format_url(invoker, name, dest, anchor)
        else
            # "%s~($\\Rightarrow{}$\\pageref{%s})" % [plain_text(name), anchor]
            # "%s~($\\Rightarrow{}$\\pageref{%s})" % [name, anchor]
            p = @deplate.parse_and_format(invoker.container, @deplate.msg('p.\\ '))
            label = clean_label(anchor)
            "#{name}~(#{p}\\pageref{#{label}})"
        end
    end
   
    def format_symbol(invoker, text)
        case text
        when "<-"
            return "$\\leftarrow{}$"
        when "->"
            return "$\\rightarrow{}$"
        when "<="
            return "$\\Leftarrow{}$"
        when "=>"
            return "$\\Rightarrow{}$"
        when "<<<"
            return "$\\Longleftarrow{}$"
        when ">>>"
            return "$\\Longrightarrow{}$"
            # when "<~"
            # return "\\{}"
        when "~>"
            add_package("latexsym")
            return "$\\leadsto{}$"
        when "<->"
            return "$\\leftrightarrow{}$"
        when "<=>"
            return "$\\Leftrightarrow{}$"
        when "<~>"
            return "$\\rightleftharpoons{}$"
        when "!="
            return "$\\neq{}$"
        when "~~"
            return "$\\approx{}$"
        when "..."
            return "\\ldots{}"
        when "--"
            return text
        when "=="
            return "$\\equiv{}$"
        when "+++"
            return "$^{*}$\\protect\\marginpar{$^{*}$\\emph{+++}}"
        when "###"
            return "$^{*}$\\protect\\marginpar{$^{*}$\\emph{\\#\\#\\#}}"
        when "???"
            return "$^{*}$\\protect\\marginpar{$^{*}$\\emph{???}}"
        when "!!!"
            return "$^{*}$\\protect\\marginpar{$^{*}$\\emph{!!!}}"
        else
            return plain_text(text)
        end
    end
    
    def doublequote_open(invoker)
        "``"
    end
    
    def doublequote_close(invoker)
        "''"
    end
    
    def singlequote_open(invoker)
        "`"
    end
    
    def singlequote_close(invoker)
        "'"
    end

    
    ################################################ Macros {{{1
    def format_index(invoker, idx)
        i = Deplate::Core.get_index_name(idx)
        # n = @deplate.parse_and_format(@container, i, false)
        # n = n.gsub(/,/, "{,}")
        n = plain_text(i).gsub(/,/, "{,}")
        return "\\protect\\index{#{n}}"
    end

    def format_footnote(invoker)
        elt = invoker.elt
        if elt
            body = elt.format_current
            if body
                return "\\footnote{%\n#{body.rstrip}%\n}"
            end
        end
        return ''
    end

    def format_ref(invoker)
        add_package('hyperref')
        args = invoker.args
        label = clean_label(invoker.text)
        p = args['p']
        prefix = invoker.args['prefix'] || '~'
        if p
            return "#{prefix}\\pageref{#{label}}"
        else
            return "#{prefix}\\ref{#{label}}"
        end
    end

    def format_linebreak(invoker)
        if invoker.args['inline']
            return '\\\\'
        else
            return '\\newline{}'
        end
    end

    # Currently assumes the use of natbib
    def format_cite(invoker)
        args    = invoker.args
        elt     = invoker.elt
        add_package('natbib', 'round')
        n   = args['n']
        p   = args['p']
        ip  = args['ip']
        np  = ip || args['np']
        y   = args['y']
        sep = args['sep'] || (np ? '' : '\ ')
        sep = @deplate.parse_and_format(invoker.container, sep) unless sep.empty?
        c   = elt
        o   = []
        o  << "[#{n}]" if n
        if p
            p = @deplate.parse_and_format(invoker.container, "#{@deplate.msg('p.\\ ')}#{p}")
            o << "[#{p}]"
        elsif n
            o << "[]"
        end
        o  = o.empty? ? '' : o.join
        if np
            cmd = if y then 'citeyear' else 'citealp' end
        elsif ip
            cmd = if y then 'citeyear' else 'citet' end
        else
            cmd = if y then 'citeyearpar' else 'citep' end
        end
        return "#{sep}\\#{cmd}#{o}{#{c.join(",")}}"
    end

    def format_subscript(invoker)
        elt = invoker.elt
        return %{$\\mathrm{_{#{elt.sub(/([{}])/, "\\\\\\1")}}}$}
    end

    def format_superscript(invoker)
        elt = invoker.elt
        return %{$\\mathrm{^{#{elt.sub(/([{}])/, "\\\\\\1")}}}$}
    end

    def format_stacked(invoker)
        elt = invoker.elt
        sup = %{#{elt[0].sub(/([{}])/, "\\\\\\1")}}
        sub = %{#{elt[1].sub(/([{}])/, "\\\\\\1")}}
        return %{$\\mathrm{^{#{sup}}_{#{sub}}}$}
    end

    def format_pagenumber(invoker)
        args = invoker.args
        if args["hd"] || args["ft"] || args["header"] || args["footer"]
            return ""
        else
            return "\\thepage{}"
        end
    end

    def format_ltx(invoker, other_args={})
        invoker.elt
    end

    # Format the math macro
    alias :format_math :format_ltx


    protected ###################################### protected {{{1
    ################################################ General {{{1
    def set_document_encoding
        enc = document_encoding()
        output_at(:pre, :fmt_packages, "\\usepackage[#{enc}]{inputenc}")
    end


    ################################################ Lists {{{1
    def format_list_enumerate_alpha(invoker, what, subtype, w, pre, post)
        if what == :open
            if defined?(@@enumerateCounters)
                @@enumerateCounters += 1
            else
                @@enumerateCounters = 0
            end
            cnt = "deplateEnumerate#{@@enumerateCounters}"
            pre = %{#{pre}\\newcounter{#{cnt}}}
            case subtype
            when "a"
                alph = "\\alph{#{cnt}}"
            when "A"
                alph = "\\Alph{#{cnt}}"
            end
            arg = "\\usecounter{#{cnt}}\\setlength{\\rightmargin}{\\leftmargin}"
            return "#{pre}\\#{w}{list}{#{alph}.}{#{arg}}#{post}"
        else
            return "#{pre}\\#{w}{list}#{post}"
        end
    end

    def list_wide?
        @deplate.variables['texLists'] == 'wide'
    end
 
    
    ################################################ List of ... {{{1
    def format_list_of_toc(invoker)
        "\\tableofcontents{}"
    end

    def format_list_of_lot(invoker)
        "\\listoftables{}"
    end
    
    def format_list_of_lof(invoker)
        "\\listoffigures{}"
    end

    def format_list_of_index(invoker)
        add_package("makeidx")
        union_at(:pre, :mod_head, "\\makeindex{}")
        "\\printindex{}"
    end

    def listing_prematter(invoker, args, id)
        type = args[:prefix]
        @deplate.endmessage("listing_#{type}", %{You might need to edit deplate.sty and define the environment #{type}List and the command \\#{type}Item.}
                                )
        nil
    end
    
    def listing_postmatter(invoker, args)
        ''
    end
    
    def listing_title(invoker, args, name)
        if name
            format_heading(nil, 1, @deplate.msg(name), {'noList' => true})
        end
    end
    
    def listing_item(invoker, args, prefix, title, heading, level, other_args)
        b = title
        # <+TBD+> Hyperlinks
        # use latex contents infrastructure?
        i = heading.plain_caption? ? nil : heading.level_as_string
        s = Deplate::ListItem.new(i, b, "Custom", "Custom", level, 0, true)
        s.opts = {:subtype => prefix, :custom => prefix}
        s
    end
    

    ################################################ Table {{{1
    def table_indented_row(invoker, row, indent, cells)
        # indent_text(cells)
        indent + cells
    end
    
    def table_normal_row(invoker, row, nth)
        args   = tabular_args(invoker)
        just   = tabular_col_justifications(invoker)
        widths = tabular_col_widths(invoker)
        acc    = []
        row.cols.each_with_index do |cell, x|
            case cell
            when :join_left
            when :join_above
                acc << ""
            when :ruler, :noruler
                raise "Shouldn't be here"
            else
                rv = with_agent(:table_cell, String, invoker, cell, row)
                wi = widths[x]
                if wi
                    case just[x]
                    when "r", "right"
                        rv = %{\\parbox[t]{#{wi}}{\\raggedleft{}#{rv}}}
                    when "c", "center"
                        rv = %{\\parbox[t]{#{wi}}{\\centering{}#{rv}}}
                    when "l", "left"
                        rv = %{\\parbox[t]{#{wi}}{\\raggedright{}#{rv}}}
                    # when "j", "justify"
                    # else
                    end
                end
                # span = cell.span_y
                # if span > 1
                #     add_package("multirow") 
                #     rv = %{\\multirow{#{span}}{*}{#{rv}}}
                # end
                span = cell.span_x
                if span > 1
                    coldef = args[x]
                    if args[x + span - 1] =~ /\|$/ and coldef !=~ /\|$/
                        coldef << "|"
                    end
                    rv = %{\\multicolumn{#{span}}{#{coldef}}{#{rv}}}
                end
                # if rv.empty?
                #     rv = "{ }"
                # end
                acc << rv 
            end
        end
        return acc
    end

    alias :table_head_row :table_normal_row
    alias :table_foot_row :table_normal_row
    alias :table_high_row :table_normal_row

    def table_horizontal_ruler(invoker, row, nth)
        acc  = []
        from = nil
        row.cols.each_with_index do | cell, i |
            unless cell.instance_of?(Symbol)
                cell = cell.cell
            end
            case cell
            when :ruler
                from = i unless from
            when :noruler, /^\s*$/
                if from
                    acc << with_agent(:table_horizontal_ruler_from_to, String, invoker, 
                                      :from => from, :to => i, :top => (i == 0))
                    from = nil
                end
            else
                invoker.log(["Malformed ruler definition", cell, row], :error)
            end
        end
        if from == 0
            acc << with_agent(:table_horizontal_ruler_from_to, String, invoker, :bottom => true)
        end
        acc.join(" ")
    end

    def table_horizontal_ruler_from_to(invoker, args={})
        from   = args[:from]
        to     = args[:to]
        top    = args[:top]    || false
        bottom = args[:bottom] || false
        unless top or bottom
            row = args[:row]
            if row

            end
        end
        if from and to
            cline = @booktabs ? "cmidrule" : "cline"
            %{\\#{cline}{#{from + 1}-#{to}}}
        else
            if @booktabs
                hline = if top
                            "toprule"
                        elsif bottom
                            "bottomrule"
                        else
                            "midrule"
                        end
            else
                hline = "hline"
            end
            %{\\#{hline}}
        end
    end

    def table_cell(invoker, cell, row)
        cell.cell
    end
    
    def is_longtable?(invoker, rown)
        args = invoker.args
        if args["long"]
            return true
        elsif args["short"]
            return false
        elsif rown
            return rown > 20
        else
            return false
        end
    end

    def table_join_cells(cells)
        if cells.kind_of?(Array)
            cells.join(" & ") + " \\\\"
        else
            cells
        end
    end

    def tabular_args(invoker, args=nil)
        colwidth  = with_agent(:tabular_col_widths, Array, invoker, args)
        coljust   = with_agent(:tabular_col_justifications, Array, invoker, args)
        vertruler = with_agent(:tabular_vertical_rulers, Array, invoker, args)
        rv        = []
        rowsize   = table_row_size(invoker.elt)
        for i in 0..(rowsize - 1)
            this = ""
            r = vertruler[i]
            if r
                this << ("|" * r.to_i)
            end
            w = colwidth[i]
            if w
                this << %{p{%s}} % w
            else
                j = coljust[i]
                case j
                when "r", "right"
                    j = "r"
                when "c", "center"
                    j = "c"
                # when "left", "justify"
                    # j = "l"
                else
                    j = "l"
                end
                this << j
            end
            rv << this
        end
        r = vertruler[rowsize]
        if r
            rv.last << ("|" * r.to_i)
        end
        return rv
    end

    def tabular_col_widths(invoker, args=nil)
        args ||= invoker.args
        Deplate::Core.props(args["cols"], "w")
    end
    
    def tabular_col_justifications(invoker, args=nil)
        args ||= invoker.args
        Deplate::Core.props(args["cols"], "j")
    end
    
    def tabular_vertical_rulers(invoker, args=nil)
        args ||= invoker.args
        Deplate::Core.props(args["cols"], "r")
    end
    
    def table_cols(invoker)
        args = invoker.args
        elt  = invoker.elt
        tabular_args(invoker).join
    end
    
    def table_table_top(invoker, capAbove)
        floatPos, alignCmd = float_options(invoker)
        acc = []
        acc << "\\begin{table}%s" % [floatPos]
        acc << alignCmd
        acc << with_agent(:table_caption, String, invoker, false) if capAbove
        note = invoker.args["note"]
        if invoker.contains_footnotes or note
            acc << "\\begin{minipage}{\\textwidth}"
            acc << alignCmd
        end
        acc << with_agent(:table_tabular_top, String, invoker)
        join_blocks(acc)
    end

    def table_table_bottom(invoker, capAbove)
        acc = []
        acc << with_agent(:table_tabular_bottom, String, invoker)
        note = with_agent(:table_note, String, invoker)
        acc << "\\end{minipage}" if invoker.contains_footnotes or note
        acc << note if note
        acc << format_label(invoker, :once)
        acc << with_agent(:table_caption, String, invoker, false) if !capAbove
        acc << "\\end{table}"
        join_blocks(acc)
    end
    
    def table_tabular_top(invoker)
        "\\begin{tabular}{#{table_cols(invoker)}}"
    end

    def table_tabular_bottom(invoker)
        "\\end{tabular}"
    end

    def table_longtable_top(invoker, capAbove)
        add_package("longtable")
        # floatPos, alignCmd = float_options(invoker)
        acc = []
        acc << "\\begin{longtable}{%s}" % table_cols(invoker)
        # <+TBD+> acc << alignCmd
        acc << "#{with_agent(:table_caption, String, invoker, true)} \\\\" if capAbove
        join_blocks(acc)
    end
    
    def table_longtable_bottom(invoker, capAbove)
        acc = []
        acc << "#{with_agent(:table_caption, String, invoker, true)} \\\\" if !capAbove
        acc << "\\end{longtable}"
        join_blocks(acc)
    end
    
    def table_top(invoker, capAbove, rown)
        acc = []
        if is_longtable?(invoker, rown)
            acc << table_longtable_top(invoker, capAbove)
        elsif invoker.caption
            acc << table_table_top(invoker, capAbove)
        else
            if invoker.contains_footnotes or invoker.args["note"]
                acc << "\\begin{minipage}{\\textwidth}"
            end
            acc << with_agent(:table_tabular_top, String, invoker)
        end
        join_blocks(acc)
    end

    def table_bottom(invoker, capAbove, rown)
        acc = []
        if is_longtable?(invoker, rown)
            acc << table_longtable_bottom(invoker, capAbove)
        elsif invoker.caption
            acc << table_table_bottom(invoker, capAbove)
        else
            acc << format_label(invoker, :once)
            acc << with_agent(:table_tabular_bottom, String, invoker)
            note = with_agent(:table_note, String, invoker)
            acc << "\\end{minipage}" if invoker.contains_footnotes or note
            acc << note if note
        end
        acc << ""
        join_blocks(acc)
    end

    def table_note(invoker)
        note = invoker.args["note"]
        note ? %{\\footnotesize{#{@deplate.parse_and_format(invoker, note)}}} : nil
    end
    
    def table_caption(invoker, do_label)
        caption = invoker.caption
        if caption
            cap = [caption.elt]
            cap << format_label(invoker, :string) if do_label
            text = with_agent(:table_caption_text, String, invoker, cap.join)
            "\\caption{#{text}}"
        elsif do_label
            format_label(invoker, :once)
        end
    end

    def table_caption_text(invoker, text)
        text
    end
   
    def table_begin_head(invoker, rown)
        nil
    end
    
    def table_end_head(invoker, rown)
        caption = invoker.caption
        if caption and is_longtable?(invoker, rown)
            "    \\endhead"
        end
    end
    
    def table_begin_body(invoker, rown)
        nil
    end
    
    def table_end_body(invoker, rown)
        # <+TBD+>
    end
    
    def table_begin_foot(invoker, rown)
        nil
    end
    
    def table_end_foot(invoker, rown)
        nil
    end
    
    def float_options(invoker)
        args = invoker.args
        if args["here"] == "H" or @deplate.variables["floatHere"] == "H"
            floatPos = "[H]"
            add_package("float")
        elsif args["here"] or @deplate.variables["floatHere"]
            floatPos = "[hptb]"
        else
            floatPos = nil
        end
        align   = args["align"] || @deplate.variables["floatAlign"]
        align ||= "center" if invoker.caption
        case align
        when "right"
            alignCmd = "\\raggedleft{}"
        when "left"
            alignCmd = "\\raggedright{}"
        when "center"
            alignCmd = "\\centering{}"
        else
            alignCmd = nil
        end
        return floatPos, alignCmd
    end

    def block_postfix(invoker)
        return invoker.inlay? ? "" : "\n"
    end

end


class Deplate::Regions::Img
    @@ImgSuffix[Deplate::Formatter::LaTeX] = Proc.new do |invoker|
        invoker.deplate.options.pdftex ? "png" : "ps"
    end
end

