# encoding: ASCII
# fmt-html.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     17-Mär-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.3598

require "deplate/formatter"

# No formatter.

class Deplate::Formatter::Plain < Deplate::Formatter
    self.myname = "plain"
    self.rx     = /plain/i
    self.suffix = '.text'

    self.label_mode     = :delegate
    self.label_delegate = []
    self.label_once     = []
    
    def initialize(deplate, args)
        super
        @color        = deplate.variables['ansiColor'] && defined?(Deplate::Color)
        @list_counter = {}
        @references   = {}
    end

    def read_bib(bibfiles)
        simple_bibtex_reader(bibfiles)
    end

    def format_label(invoker, mode=nil, label=nil)
        ''
    end

    def format_figure(invoker, inline=false, elt=nil)
        elt ||= invoker.elt
        unless elt.kind_of?(String)
            invoker.log(['Unexpected argument', elt.class], :error)
            elt = elt.to_s
        end
        if inline or invoker.args['inline']
            include_image(invoker, elt, invoker.args, true)
        else
            acc = []
            fig     = @deplate.msg("Figure")
            caption = invoker.caption
            if caption
                capAbove = !(caption && caption.args && caption.args.include?("below"))
                lev      = invoker.level_as_string
                cap = %{#{fig} #{lev}: #{caption.elt}}
            else
                capAbove = false
            end
            if caption and capAbove
                acc << cap
            end
            acc << include_image(invoker, elt, invoker.args)
            if caption and !capAbove
                acc << cap
            end
            acc << ""
            join_blocks(acc)
        end
    end

    def include_image_general(invoker, file, args, inline=false)
        file = args['file'] if args['file']
        if inline or !@deplate.variables['asciiArt']
            return "[#{args["alt"] || @deplate.variables['imgAlt'] || file}]"
        else
            file = use_image_filename(file, args)
            if File.exist?(file)
                acc = [file]
                args[:deplate] ||= @deplate
                # case @deplate.variables['asciiArt']
                # else
                return Deplate::External.jave(invoker, file, args)
                # end
            end
        end
    end

    def image_suffixes
        # [".png", ".jpeg", ".jpg", ".gif", ".bmp"]
        ['.jpeg', '.jpg', '.gif', '.bmp']
    end

    alias :format_IMG :format_figure

    alias :format_MAKETITLE :format_title
    
    def format_note(invoker)
        indent = "  #{invoker.marker * 3} "
        wrap_text(indent + invoker.elt, :indent => indent) + "\n"
    end

    def format_table(invoker)
        elt        = invoker.elt
        args       = invoker.args
        level_as_string = invoker.level_as_string
        caption    = invoker.caption
        capAbove   = !(caption && caption.args && caption.args.include?("below"))

        widths = []
        elt.each_with_index do |row, y|
            row.cols.each_with_index do |cell, x|
                case cell
                when :join_left, :join_above
                when :ruler, :noruler
                else
                    t = cell.cell.split(/\n/).collect {|l| l.size}
                    s = t.max || 0
                    w = widths[x]
                    if !w or w < s
                        widths[x] = s
                    end
                end
            end
        end

        ruler = ["+-", widths.collect {|w| "-" * w}.join("-+-"), "-+"].join
        acc = []
        
        if caption and capAbove
            acc << %{#{@deplate.msg("Table")} #{level_as_string}: #{caption.elt}}
        end
        
        acc_head = []
        acc_foot = []
        acc_body = []
        elt.each_with_index do |r, n|
            if r.is_ruler
                # acc_body << ruler
            elsif r.head
                acc_head << formatted_table_row(n, r, widths)
            elsif r.foot
                acc_foot << formatted_table_row(n, r, widths)
            else
                acc_body << formatted_table_row(n, r, widths)
            end
        end

        acc << ruler
        unless acc_head.empty?
            acc << acc_head << ruler
        end
        acc << acc_body
        unless acc_foot.empty?
            acc << ruler << acc_foot
        end
        acc << ruler

        note = invoker.args["note"]
        if note
            acc << @deplate.parse_and_format(invoker, note)
        end
        
        if caption and !capAbove
            acc << %{#{@deplate.msg("Table")} #{level_as_string}: #{caption.elt}}
        end

        acc << ""
        join_blocks(acc)
    end
    
    def formatted_table_row(y, r, widths)
        n   = 1
        i   = 0
        acc = []
        cols = r.cols.collect do |c|
            if c.kind_of?(Symbol)
                c
            else
                c.cell.gsub(/\n*(.*)\n*/, "\\1")
            end
        end
        while i < n
            row = []
            r.cols.each_with_index do |c, x|
                case c
                when :join_left
                when :join_above
                    w = widths[x]
                    row << %{%-#{w}s} % " "
                when :ruler, :noruler
                    w = get_width(x, c.span_x, widths)
                    row << %{%-#{w}s} % (i == 0 ? "-" : " ")
                else
                    w  = get_width(x, c.span_x, widths)
                    t  = c.cell.split(/\n/)
                    ts = t.size
                    if ts > n
                        n = ts
                    end
                    row << %{%-#{w}s} % (t[i] || " ")
                end
            end
            acc << "| #{row.join(" | ")} |"
            i += 1
        end
        acc.join("\n")
    end
    private :formatted_table_row
   
    def get_width(x, span, widths)
        w = widths[x]
        for j in 1..(span - 1)
            w += 3 + widths[x + j]
        end
        w
    end
    private :get_width
    
    def format_heading(invoker, level=nil, elt=nil)
        level ||= invoker.level
        elt   ||= invoker.elt
        ul      = ["", "=", "~", "-", '"', "'"][level]
        if invoker and invoker.level_as_string
            elt = [invoker.level_as_string, elt].join(" ")
        end
        if ul
            elt = [nil, elt, ul * elt.size, nil].join("\n")
            # [elt, ul * elt.size].join("\n")
        end
        if @color
            elt = Deplate::Color.bold(elt)
        end
        elt
    end

    def format_list(invoker)
        printable_list(invoker) + "\n"
    end
    
    def format_list_env(invoker, type, level, what, subtype=nil)
        case what
        when :open
            @list_counter[type] ||= []
            @list_counter[type].push(0)
        when :close
            @list_counter[type].pop
        end
        nil
    end

    LIST_ITEMIZE_MARKERS   = ['*', '*', '+', '+', '-', '-']
    LIST_ITEMIZE_MARKERS_N = LIST_ITEMIZE_MARKERS.size
    # <+TBD+>Alphabethic lists give strange counters if the index passes beyond 'z'
    def format_list_item(invoker, type, level, item, args={})
        # indent = format_indent(level, true)
        indent   = "  " * level
        explicit = args[:explicit]
        case type
        when "Ordered"
            if explicit or item.explicit and item.item
                # and !item.item.empty?
                i = item.item
            else
                i = @list_counter[type][-1] += 1
                case list_subtype(type, item)
                when "a"
                    i = "%c" % (96 + i)
                when "A"
                    i = "%c" % (64 + i)
                else
                    i = i.to_s
                end
                i += '.' unless i.empty?
            end
            i += ' ' unless i.empty?
            return wrap_text([indent, i, item.body].join, :hanging => 2), :none
        when "Itemize"
            if explicit or item.explicit and item.item
                # and !item.item.empty?
                i = item.item
            elsif (itemize_markers = @deplate.variables['itemizeMarkers'])
                itemize_markers = Deplate::Core.split_list(itemize_markers)
                i = itemize_markers[(level % itemize_markers.size) - 1]
            else
                i = LIST_ITEMIZE_MARKERS[level % LIST_ITEMIZE_MARKERS_N]
            end
            unless i.empty?
                i += " "
            end
            return wrap_text([indent, i, item.body].join, :hanging => 2), :none
        when 'Task'
            pri  = item.opts[:priority]
            cat  = item.opts[:category]
            done = item.opts[:done] ? 'done' : nil
            due  = item.opts[:due]
            task = [cat, pri]
            task << " #{due}" if due
            body = ['{', task, '} ', item.body].join
            body = indent_text(wrap_text(body), 
                               :mult => level,
                               :hanging => true,
                               :indent => indent
                              )
            return body, :none
        when "Description"
            accum = [indent, item.item, "\n"]
            accum << indent << "  " << item.body if item.body
            return wrap_text(accum.join), :none
        when "Paragraph"
            t = "\n" + wrap_text(indent + item.body)
            # t = wrap_text(indent + item.body)
            return t, nil
        when 'Container'
            # t = "\n" + wrap_text(indent + item.body)
            t = "\n" + item.body
            return t, nil
        else
            invoker.log(['Unknown list type', type], :error)
        end
    end

    def format_verbatim(invoker, text=nil)
        text = invoker.elt
        indent_text(text) + "\n"
    end

    def format_abstract(invoker)
        text = invoker.elt
        # wrap_text("    " + text) + "\n"
        indent_text(text) + "\n"
    end

    def format_quote(invoker)
        text = invoker.elt
        # wrap_text("> " + text, :indent => "> ") + "\n"
        indent_text(text, :indent => '> ') + "\n"
    end

    def format_title(invoker)
        acc = []
        for i, c in [["title",      %{%s}],
                     ["author",     %{%s}], 
                     ["authornote", %{%s}],
                     ["date",       %{%s}]]
            ii = @deplate.get_clip(i)
            acc << wrap_text(c % ii.elt) if ii
        end
        acc = acc.join("\n\n")
        s   = acc.collect {|l| l.size}.max
        r   = "~" * s
        [r, acc, r, nil].join("\n\n")
    end

    def format_MAKEBIB(invoker)
        format_bibliography(invoker) do |key, labels, text|
            wrap_text("  " + text, :hanging => 4)
        end
    end

    def format_IDX(invoker)
        nil
    end

    def format_emphasize(invoker, text=nil)
        text ||= invoker.elt || invoker.text
        if @color
            # Deplate::Color.italic(text)
            Deplate::Color.bold(text)
        else
            text
        end
    end

    def format_code(invoker, text=nil)
        text ||= invoker.elt || invoker.text
        text
    end

    # <+TBD+> [1] + urls at the bottom
    def format_url(invoker, name, dest, anchor, literal=false)
        hlink = Deplate::HyperLink.url_anchor(dest, anchor)
        fn    = @references[hlink]
        unless fn
            idx = @deplate.footnote_last_idx += 1
            fn  = "[#{idx}]"
            @references[hlink] = fn
            if @color
                hlink = Deplate::Color.underline(hlink)
            end
            output_at(:body, :footnotes, %{#{fn} #{hlink}})
        end
        if name and !(name.empty?)
            rv = [name, fn].join
        else
            rv = fn
        end
        if @color
            rv = Deplate::Color.underline(rv)
        end
        rv
    end

    alias :format_wiki :format_url
    # def format_wiki(invoker, name, dest, anchor)
    #     idx = @deplate.footnote_last_idx += 1
    #     fn = "[#{idx}]"
    #     invoker.container.postponed_format << Proc.new do |container|
    #         output_at(:body, :footnotes, %{#{fn} #{Deplate::HyperLink.url_anchor(dest, anchor)}})
    #     end
    #     [name, fn].join(" ")
    # end

    def format_symbol(invoker, text)
        text
    end

    def format_index(invoker, idx)
        ''
    end

    def format_footnote(invoker)
        elt = invoker.elt
        if elt and elt.elt and elt.fn_consumed
            lab = elt.fn_label
            if !@deplate.footnotes_used.include?(lab)
                idx          = @deplate.footnote_last_idx +=1
                lab          = "[#{idx}]"
                elt.fn_n     = idx
                elt.fn_label = lab
                @deplate.footnotes_used << lab
                # text         = wrap_text("#{lab} #{elt.format_current}", :hanging => 4)
                text         = [
                    lab,
                    indent_text(elt.format_current, :indent => '', :hanging => 4)
                ].join(' ')
                # invoker.container.postponed_format << Proc.new do |container|
                    output_at(:body, :footnotes, text)
                # end
            end
        end
        return elt.fn_label
    end

    def format_ref(invoker)
        prefix = invoker.args['prefix'] || ' '
        text = (invoker.text && @deplate.labels[invoker.text]) || ''
        prefix + text
    end

    def format_break(invoker)
        '-' * 72
    end
    
    def format_anchor(invoker)
        ''
    end
    
    def format_paragraph(invoker)
        wrap_text(invoker.elt) + "\n"
    end
    
    def format_header(invoker)
        format_header_or_footer(invoker, :pre, :header)
        nil
    end

    def format_footer(invoker)
        format_header_or_footer(invoker, :post, :footer)
        nil
    end
    
    def format_header_or_footer(invoker, type, slot)
        args = invoker.args
        acc  = [""]
        for e in invoker.elt
            e.args[:dontWrapTable] = true
            acc << e.format_current
        end
        acc << ""
        output_at(type, slot, *acc)
        nil
    end
    private :format_header_or_footer
    
    def format_pagebreak(invoker, style=nil, major=false)
        ""
    end
    
    def doublequote_open(invoker)
        '"'
    end
    
    def doublequote_close(invoker)
        '"'
    end
    
    def singlequote_open(invoker)
        "'"
    end
    
    def singlequote_close(invoker)
        "'"
    end
    
    def format_linebreak(invoker)
        "\n"
    end
    
    def format_subscript(invoker)
        invoker.elt
    end
    
    def format_superscript(invoker)
        invoker.elt
    end
    
    def format_stacked(invoker)
        invoker.elt
    end
    
    def format_pagenumber(invoker)
        return ""
    end

    def format_list_of_toc(invoker)
        format_list_of(invoker, 
                       :title => "Table of Contents", 
                       :prefix => "hd", 
                       :listing => 'toc', :flat => false)
    end

    def format_list_of_minitoc(invoker)
        data = @deplate.options.listings.get('toc').find_all {|e| e.level == 1}
        format_list_of(invoker, 
                       :title => "Contents", 
                       :prefix => "hd", 
                       :data => data, :flat => false, 
                       :img => @variables["navGif"],
                       :html_class => "minitoc") do |hd|
            hd.args["shortcaption"] || hd.args["id"]
        end
    end

    def format_list_of_lot(invoker)
        format_list_of(invoker, 
                       :title => "List of Tables", 
                       :prefix => "tab", 
                       :listing => 'lot', :flat => true)
    end

    def format_list_of_lof(invoker)
        format_list_of(invoker, 
                       :title => "List of Figures",
                       :prefix => "fig", 
                       :listing => 'lof', :flat => true)
    end

    def format_list_of_index(invoker)
        format_the_index(invoker, "Index", @deplate.index, "idx", true)
    end

    def listing_prematter(invoker, args, id)
        nil
    end
    
    def listing_postmatter(invoker, args)
        ''
    end
    
    def listing_title(invoker, args, name)
        if name
            format_heading(nil, 1, @deplate.msg(name))
        end
    end
    
    def listing_item(invoker, args, prefix, title, heading, level, other_args)
        v = [heading.level_as_string, title].join(' ') unless heading.plain_caption?
        s = Deplate::ListItem.new('', v, 'Itemize', 'Itemize', level, 0, true)
        s
    end

    def format_the_index(invoker, name, data, prefix="", flat=false, other_args={})
        accum  = []
        chars  = []
        
        # accum << format_list_env(invoker, "Description", 0, :open)
        for n, arr in sort_index_entries(data)
            cht = get_first_char(n, true)
            if !chars.include?(cht)
                chars << cht
                accum << format_list_env(invoker, "Description", 0, :close) unless accum.empty?
                accum << format_heading(nil, 2, cht)
                accum << format_list_env(invoker, "Description", 0, :open)
            end
            acc = []
            for i in arr
                ff = @deplate.dest
                if i.file || i.level_as_string
                    f = i.file || invoker.output_file_name(:level_as_string => i.level_as_string,
                                                           :relative => invoker)
                    if f == ff
                        f = ''
                        l = i.level_as_string
                        if l and !l.empty?
                            t = l
                        elsif @deplate.options.multi_file_output
                            t = '<>'
                        else
                            t = 'I'
                        end
                    else
                        t = @deplate.file_with_suffix(f, '', true)
                    end
                    acc << t
                else
                    invoker.log(['Index: Neither file nor level defined: dropping', i.label], :error)
                end
            end
            s = Deplate::ListItem.new(plain_text(n), acc.join(', '))
            ot, et = format_list_item(invoker, 'Description', 0, s)
            accum << ot
            accum << et unless et == :none
        end
        accum << format_list_env(invoker, 'Description', 0, :close)
        acc = []
        acc << chars.join(' ')
        acc << accum.compact.join("\n")
        acc << ''
        join_blocks(acc)
    end
end


class Deplate::Command::MAKEBIB
    accumulate_pre(self, Deplate::Formatter::Plain) do |src, array, deplate, text, match, args, cmd|
        unless args['plain']
            n = deplate.msg('Bibliography')
            m = [nil, '*', n]
            o = Deplate::Element::Heading.new(deplate, src, n, m).finish
            o.update_options(args)
            deplate.options.html_makebib_heading = o
            array << o
        end
    end
end


class Deplate::Command::LIST
    accumulate_pre(self, Deplate::Formatter::Plain) do |src, array, deplate, text, match, args, cmd|
        if text == 'index' and !args['plain'] and !args['noTitle']
            n = deplate.msg('Index')
            m = [nil, '*', n]
            h = Deplate::Element::Heading.new(deplate, src, n, m).finish
            h.update_options(args)
            array << h
        end
    end
end


# vim: ff=unix
