# encoding: ASCII
# structured.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     17-Mär-2004.
# @Last Change: 2010-10-07.
# @Revision:    0.2755
# 
# TODO:
# - am Ende des Dokuments muss ein Stapel mit offenen tags abgearbeitet werden

require "deplate/formatter"
require "deplate/abstract-class"

# An abstract formatter

class Deplate::Formatter::Structured < Deplate::Formatter
    @@bibentries      = {}
    @@openLabels      = []

    self.label_delegate = [
        # :format_heading, 
        :format_LIST,
        :format_anchor,
    ]

    self.label_once = [
        :format_list_env,
        :format_table,
        :format_IMG,
        :format_IDX,
        :format_paragraph,
    ]


    ################################################ Setup {{{1
    def read_bib(bibfiles)
        simple_bibtex_reader(bibfiles)
    end

    def output_at(type, slot, text)
        ind = @deplate.options.indentation_level.last
        if ind > 0
            text = indent_text(text, :mult => ind)
        end
        super(type, slot, text)
    end
    

    ################################################ Lists {{{1
    def format_list_item(invoker, type, level, item, args={})
        args     = invoker.args
        explicit = args[:explicit]
        # $stderr << "Item #{type}: #{item.body}\n" if $DEBUG
        case type
        when "Ordered"
            open  = get_item_numbered_open(args, item.item, item.body)
            close = get_item_numbered_close(args)
        when "Itemize"
            open  = get_item_itemize_open(args, item.item, item.body)
            close = get_item_itemize_close(args)
        when "Description"
            open  = get_item_description_open(args, item.item, item.body)
            close = get_item_description_close(args)
        when 'Task'
            open  = get_item_task_open(args, item.item, item.body, item.opts)
            close = get_item_task_close(args)
        when "Paragraph"
            open  = get_item_paragraph(args, item.item, item.body)
            close = nil
        when 'Container'
            open  = item.body
            close = nil
        else
            f = item.preformatted
            if f
                open, close = f
            else
                raise "Unknown list type: #{item.inspect}"
            end
        end
        if type != 'Container'
            # open = indent_text(open, level, :shift => true)
            open = indent_text(open, :mult => level)
        end
        # close = indent_text(close, level, :shift => true)
        close = indent_text(close, :mult => level)
        return open, close
    end
    
    def_abstract :get_item_numbered_open, :get_item_description_close, :get_item_paragraph
    
    def format_list_env(invoker, type, level, what, subtype=nil)
        args = invoker.args
        case type
        when "Ordered"
            if what == :open
                tag = get_list_numbered_open(args, subtype)
            elsif what == :close
                tag = get_list_numbered_close(args)
            end
        when "Itemize"
            if what == :open
                tag = get_list_itemize_open(args)
            elsif what == :close
                tag = get_list_itemize_close(args)
            end
        when 'Task'
            if what == :open
                tag = get_list_task_open(args)
            elsif what == :close
                tag = get_list_task_close(args)
            end
        when "Description"
            if what == :open
                tag = get_list_description_open(args)
            elsif what == :close
                tag = get_list_description_close(args)
            end
        when nil
            invoker.log('List type is nil', :debug)
        else
            raise "Unknown list type: #{type}"
        end
        # return indent_text(tag, level, :shift => true)
        return indent_text(tag, :mult => level)
    end

    def_abstract :get_list_numbered_open, :get_list_numbered_close
    def_abstract :get_list_itemize_open, :get_list_itemize_close
    def_abstract :get_list_description_open, :get_list_description_close

    
    ################################################ General {{{1
    def format_label(invoker, mode=nil, label=nil)
        args  = invoker.args
        id    = use_id(args)
        label = use_labels(args, label || invoker.label)
        acc   = []
        unless !label or label.empty?
            case mode
            when :before
                for l in label
                    acc << get_label(args, l, mode)
                    @@openLabels << l
                end
            when :after
                for l in label
                    if @@openLabels.delete(l)
                        acc << get_label(args, l, mode)
                    end
                end
            when :once
                for l in label
                    text = if block_given? then yield(l) else '' end
                    acc << get_label(args, l, mode, text)
                end
            when :closeOpen
                while !@@openLabels.empty?
                    l = @@openLabels.pop
                    acc << format_label(invoker, :after)
                end
            else
                for l in label.uniq
                    text = if block_given? then yield(l) else '' end
                    acc << get_label(args, l, mode, text)
                end
            end
        end
        join_inline(acc)
    end

    def format_figure(invoker, inline=false, elt=nil)
        elt ||= invoker.elt
        args  = invoker.args
        if inline
            include_image(invoker, elt, args, inline)
        else
            caption  = invoker.caption
            fig      = @deplate.msg('Figure')
            capAbove = !(caption && caption.args && caption.args.include?('below'))
            if caption
                ti  = %{#{fig} #{invoker.level_as_string}}
                cap = get_figure_caption(args, ti, caption.elt, capAbove)
            else
                cap = nil
            end
            get_figure(args, cap, include_image(invoker, elt, args))
        end
    end

    def_abstract :get_figure_caption, :get_figure

    def include_image_general(invoker, file, args, inline=false)
        f    = File.basename(file, '*')
        file = use_image_filename(file, args)
        return get_image(args, file, f, inline)
    end

    def_abstract :get_image, :image_suffixes


    ################################################ Elements {{{1
    def format_note(invoker)
        get_note(invoker.args, invoker.marker, invoker.elt)
    end

    def_abstract :get_note
    
    def format_table(invoker)
        elt      = invoker.elt
        args     = invoker.args
        caption  = invoker.caption
        capAbove = !(caption && caption.args && caption.args.include?("below"))
        table    = []
        if caption
            cap   = %{#{@deplate.msg("Table")} #{invoker.level_as_string}}
            title = get_table_caption(args, cap, caption.elt, capAbove)
        else
            title = nil
        end
        table << get_table_group_open(args, table_row_size(elt))
        mode  = nil
        accum = {
            "head" => [],
            "body" => [],
            "foot" => [],
        }
        elt.each_with_index do |row, y|
            if row.head
                nextmode = "head"
            elsif row.foot
                nextmode = "foot"
            elsif row.is_ruler
                # <+TBD+>
                next
            else
                nextmode = "body"
            end
            acc = accum[nextmode]
            catch(:next) do
                t = []
                row.cols.each_with_index do |cell, x|
                    case cell
                    when :join_left, :join_above
                    when :ruler, :noruler
                        throw :next
                    else
                        c = cell.cell
                        # if row.head
                            # c = get_emphasize(args, c)
                        # end
                        t << indent_text(get_table_cell(args, c, y, x, cell.span_x, cell.span_y))
                    end
                end
                acc << get_table_row_open(args)
                acc << join_blocks(t)
                acc << get_table_row_close(args)
            end
        end
        for type in get_table_order
            acc = accum[type]
            unless acc.empty?
                table << send("get_table_#{type}_open", args)
                table << indent_text(join_blocks(acc))
                table << send("get_table_#{type}_close", args)
            end
        end
        table << get_table_group_close(args)
        note = args["note"]
        if note
            note = @deplate.parse_and_format(invoker, note)
            acc << get_table_note(args, note)
        end

        get_table(args, title, join_blocks(table))
    end

    def_abstract :get_table, :get_table_row_open, :get_table_row_close, :get_table_group_open, :get_table_group_close, :get_table_cell, :get_table_note
    
    def format_heading(invoker)
        acc = []
        acc << close_headings(invoker.level)
        acc << format_heading_open(invoker)
        @deplate.options.headings << invoker
        join_blocks(acc)
    end

    def format_list(invoker)
        printable_list(invoker)
    end

    def format_break(invoker)
        format_pagebreak(invoker, "break")
    end

    def format_anchor(invoker)
        format_label(invoker, :once)
    end

    def format_paragraph(invoker)
        get_paragraph(invoker.args, invoker.elt)
    end


    ################################################ Regions {{{1
    def format_verbatim(invoker, text=nil)
        text = invoker.elt unless text
        args = invoker.args
        @deplate.options.indentation_level << 0
        invoker.postponed_format << Proc.new do |container|
            container.deplate.options.indentation_level.pop
        end
        get_pre_format(args, text)
    end

    def format_abstract(invoker)
        get_block_abstract(invoker.args, invoker.elt)
    end

    def_abstract :get_block_abstract

    def format_quote(invoker)
        args = invoker.args
        elt  = invoker.elt
        if args["long"]
            get_block_quote(args, elt)
        else
            get_block_longquote(args, elt)
        end
    end

    def_abstract :get_block_longquote, :get_block_quote
    
    def format_header(invoker)
        format_header_or_footer(invoker, :pre, :header, :get_header)
    end

    def_abstract :get_header

    def format_footer(invoker)
        format_header_or_footer(invoker, :post, :footer, :get_footer)
    end

    def_abstract :get_footer


    ################################################ Commands {{{1
    def format_title(invoker)
        args = invoker.args
        acc = []
        for i, c in [["title",      :get_title_title],
                     ["author",     :get_title_author], 
                     ["authornote", :get_title_authornote],
                     ["date",       :get_title_date]]
            ii = @deplate.get_clip(i)
            acc << send(c, args, ii.elt) if ii
        end
        get_title(args, join_blocks(acc), args["page"])
    end

    def_abstract :get_title, :get_title_date, :get_title_authornote, :get_title_author, :get_title_title

    alias :format_IMG :format_figure

    alias :format_MAKETITLE :format_title

    def format_MAKEBIB(invoker)
        args = invoker.args
        bib  = format_bibliography(invoker) do |key, labels, text|
            get_bib_entry(args, key, text)
        end
        title = @deplate.msg("Bibliography")
        get_bib(args, title, bib)
    end

    def_abstract :get_bib, :get_bib_entry

    def format_IDX(invoker)
        invoker.elt
    end

    def format_pagebreak(invoker, style=nil, major=false)
        case style
        when "title"
            nil
        when "list"
            nil
        else
            get_pagebreak(invoker.args)
        end
    end


    ################################################ Particles {{{1
    def format_emphasize(invoker, text=nil)
        text ||= invoker.elt || invoker.text
        args = invoker.args
        get_emphasize(args, text)
    end

    def_abstract :get_emphasize

    def format_code(invoker, text=nil)
        text ||= invoker.elt || invoker.text
        args = invoker.args
        get_code(args, plain_text(text, true, false))
    end
    
    def_abstract :get_code
    
    def format_url(invoker, name, dest, anchor, literal=false)
        dest = Deplate::HyperLink.url_anchor(dest, anchor)
        args = invoker.args
        get_url(args, name, dest, anchor)
    end
        
    def_abstract :get_url
    
    def format_wiki(invoker, name, dest, anchor)
        if dest.empty? and (name.empty? or name == anchor)
            get_ref(invoker.args, '', anchor, invoker.top_heading.get_id)
        else
            dest = Deplate::HyperLink.url_anchor(dest, anchor)
            args = invoker.args
            get_wiki(args, name, dest, anchor)
        end
    end
 
    def_abstract :get_wiki

    
    ################################################ Macros {{{1
    def format_index(invoker, idx)
        args = invoker.args
        i = Deplate::Core.get_index_name(idx)
        n = plain_text(i).gsub(/,/, "{,}")
        # n = i.gsub(/,/, "{,}")
        return get_index(args, idx.label, n)
    end

    def format_footnote(invoker)
        args = invoker.args
        elt = invoker.elt
        if elt and elt.elt and elt.fn_consumed
            lab = elt.fn_label ||= elt.args['id']
            if lab
                body = elt.format_current
                if @deplate.footnotes_used.include?(lab)
                    return get_footnote_ref(args, lab, body)
                else
                    @deplate.footnotes_used << lab
                    @deplate.footnote_last_idx +=1
                    return get_footnote(args, lab, body)
                end
            else
                invoker.log(['Internal error', 'No footnote label', body, elt ? elt : ''], :error)
            end
        end
        return ''
    end

    def_abstract :get_footnote, :get_footnote_ref

    def format_ref(invoker)
        args = invoker.args
        text = invoker.text
        container = invoker.container
        o = @deplate.label_aliases[text]
        if o
            t   = o.top_heading.get_id
            f   = @deplate.get_filename_for_label(invoker, text)
            # f0  = container.output_file_name
            # f   = container.output_file_name(:label => text)
            # f   = '' if f == f0
            ref = get_ref(args, f, text, t)
        else
            log(['Undefined label', text], :error)
            ref = '??'
        end
        prefix = invoker.args['prefix'] || nonbreakingspace(nil)
        return prefix + ref
    end

    def_abstract :get_ref

    def format_linebreak(invoker)
        return get_linebreak(invoker.args, invoker.container)
    end

    def_abstract :get_linebreak

    def format_cite(invoker)
        args = invoker.args
        elt  = invoker.elt
        container = invoker.container
        n  = args['n']
        p  = args['p']
        acc = []
        for c in elt
            cc = bib_entry(c)
            if cc
                e  = {}
                yr = cc['year'] || ''
                e[:year] = yr
                if n
                    e[:note] = @deplate.parse_and_format(container, n)
                    n        = nil
                end
                if p
                    p = @deplate.parse_and_format(container, "#{@deplate.msg("p.\\ ")}#{p}")
                    e[:pages] = p
                end
                nm = cc['author'] || cc['editor']
                if nm
                    if nm =~ /^\{(.*?)\}$/
                        nm = [[$1]]
                    else
                        nm = nm.gsub(/\s+/, ' ').split(/ +and +/).collect do |a|
                            a.scan(/\w+$/)
                        end
                    end
                    e[:name] = nm
                else
                    e[:name] = c
                end
                e[:id] = c
                acc << e
            end
        end
        return get_citation(args, acc)
    end

    def format_subscript(invoker)
        return get_subscript(invoker.args, invoker.elt)
    end

    def_abstract :get_subscript

    def format_superscript(invoker)
        return get_superscript(invoker.args, invoker.elt)
    end

    def_abstract :get_superscript

    def format_stacked(invoker)
        elt = invoker.elt
        return get_stacked(invoker.args, elt[0], elt[1])
    end

    def format_pagenumber(invoker)
        # <+TBD+>
        return ""
    end


    protected ###################################### protected {{{1
    ################################################ General {{{1
    def format_header_or_footer(invoker, type, slot, get_method)
        accum = []
        for e in invoker.elt
            e.doc_type = :array
            e.doc_slot = accum
            e.format_current
        end
        output_preferably_at(invoker, type, slot, send(get_method, invoker.args, join_blocks(accum)))
    end

    def index_entry_label(text)
        return "idxEntry00" + text.gsub(/\W/, "00")
    end

    
    ################################################ Bibs {{{1
    def get_cited(args, entries)
        acc = []
        for e in entries
            n = e[:note] ? "%s " % e[:note] : ""
            a = e[:name]
            case a
            when Array
                a = a.join(', ')
            end
            y = e[:year]
            p = e[:pages] ? ": %s" % e[:pages] : ""
            if a and y
                m = "%s %s" % [a, y].flatten
            else
                m = a || y
            end
            acc << [n, m, p].flatten.join
        end
        acc.join("; ")
    end

    def get_citation(args, entries)
        rv = get_cited(args, entries)
        if args["np"]
            return rv
        else
            return "%s(%s)" % [nonbreakingspace(nil), rv]
        end
    end

    alias :format_bib_entry_re_structured :format_bib_entry
    def format_bib_entry(invoker, key, bibdef)
        args = invoker.args
        # bib = Hash[*bibdef.flatten]
        bib = bibdef
        be  = ["author", "title", "pages"]
        entry = {}
        process_bib_entry_part(invoker, args, entry, bib, be)
        # for e in be
        #     ee = bib[e]
        #     if ee
        #         ee = simple_latex_reformat(ee)
        #         ee = @deplate.parse_and_format(invoker.container, ee)
        #         entry[e] = self.send("get_bib_#{e}", args, )
        #     end
        # end
        container = {}
        bc  = ['editor', 'year', 'booktitle', 'publisher', 'journal', 'volume', 'number']
        process_bib_entry_part(invoker, args, container, bib, bc)
        # for e in bc
        #     ee = bib[e]
        #     container[e] = self.send("get_bib_%s" % e, args, simple_latex_reformat(ee)) if ee
        # end
        return get_bib_relation(args, bib['_type'], entry, container)
    end

    def process_bib_entry_part(invoker, args, accum, bibdef, parts)
        for e in parts
            ee = bibdef[e]
            if ee
                ee = simple_latex_reformat(ee)
                ee = @deplate.parse_and_format(invoker, ee, false, :excluded => [
                                               Deplate::Particle::Macro,
                                               Deplate::Particle::CurlyBrace,
                                               Deplate::HyperLink::Extended,
                                               Deplate::HyperLink::Simple,
                                               Deplate::HyperLink::Url,
                ])
                accum[e] = self.send("get_bib_#{e}", args, ee)
            end
        end
    end
                               
    def_abstract :get_bib_relation, :get_bib_editor, :get_bib_year, :get_bib_booktitle, 
        :get_bib_publisher, :get_bib_journal, :get_bib_volume, :get_bib_number, 
        :get_bib_author, :get_bib_title, :get_bib_pages


    
    ################################################ Headings {{{1
    def format_heading_open(invoker)
        l = format_label(invoker)
        @deplate.options.indentation_level << invoker.level
        invoker.postponed_format << Proc.new do |container|
            container.deplate.options.indentation_level << (container.level + 1)
        end
        get_heading_open(invoker.args, invoker.level, invoker.level_as_string, invoker.elt, l)
    end

    def format_heading_close(invoker)
        @deplate.options.indentation_level.pop
        @deplate.options.indentation_level.pop
        # invoker.postponed_format << Proc.new do |container|
        #     container.deplate.options.indentation_level.pop
        # end
        get_heading_close(invoker.args, invoker.level)
    end



    ################################################ List of ... {{{1
    def format_list_of_contents(invoker)
        format_list_of(invoker, 
                       :title => 'Table of Contents', 
                       :prefix => 'hd', 
                       :listing => 'toc',
                       :flat => false)
    end
    alias :format_list_of_toc :format_list_of_contents

    def format_list_of_minitoc(invoker)
        # data = @deplate.options.listings.get('toc').find_all {|e| e.level == 1}
        # format_list_of(invoker, "Contents", "hd", 
        #                :data => data, :flat => false, 
        #                :img => @variables["navGif"],
        #                :html_class => "minitoc") do |hd|
        #     hd.args["shortcaption"] || hd.args["id"]
        # end
    end

    def format_list_of_tables(invoker)
        get_list_of_tables(invoker.args, @deplate.options.listings.get('lot'))
    end

    def_abstract :get_list_of_tables

    def format_list_of_lof(invoker)
        get_list_of_figures(invoker.args, @deplate.options.listings.get('lof'))
    end

    def_abstract :get_list_of_figures
    
    def format_list_of_index(invoker)
        get_list_of_index(invoker.args, @deplate.index)
    end

    def_abstract :get_list_of_index

    # def format_list_of(invoker, other_args)
    #     args   = invoker.args
    #     name   = other_args[:title]
    #     prefix = other_args[:prefix]
    #     data   = other_args[:data]
    #     unless data
    #         list = other_args[:listing]
    #         data = invoker.deplate.options.listings.get(list)
    #         unless data
    #             invoker.log(['Unknown list', list], :error)
    #         end
    #     end
    #     flat = other_args[:flat] || false
    #     name = args["title"] || name
    #     acc  = []
    #     acc << get_contents_open(args, prefix)
    #     ll = 1
    #     accData = []
    #     for hd in data
    #         unless hd.args["noList"]
    #             l = if flat then 1 else hd.level end
    #             f = hd.output_file_name(:relative => invoker)
    #             d = f + "#" + @deplate.elt_label(prefix, hd.level_as_string)
    #             v = if hd.caption then hd.caption.elt else v = hd.elt.dup end
    #             v = [hd.level_as_string, v].join(" ")
    #             b = format_url(invoker, v, d, nil, true)
    #             s = Deplate::ListItem.new(nil, b, "Itemize", "Itemize", l, 0, true)
    #             accData << s
    #         end
    #     end
    #     acc << get_contents_list(args, prefix, accData)
    #     acc << get_contents_close(args, prefix)
    #     join_blocks(acc)
    # end

    # <+TBD+>
    def format_the_index(invoker, name, data, prefix="", flat=false)
        accum  = []
        chars  = []
        
        # accum << get_index_open(@args)
        for n, arr in invoker.sort_index_entries(data)
            cht = get_first_char(n, true)
            if !chars.include?(cht)
                chars << cht
                lab = format_label(invoker, :string, [format_index_hd_label(cht)])
                accum << get_index_group_close(@args)
                accum << get_index_toc_entry(@args, cht, lab)
                accum << get_index_group_open(@args)
            end
            acc = []
            for i in arr
                ff = @deplate.dest
                f  = i.file || invoker.output_file_name(:level_as_string => i.level_as_string, 
                                                        :relative => invoker)
                if f == ff
                    f = ""
                    l = i.level_as_string
                    if l and !l.empty?
                        t = l
                    elsif @deplate.options.multi_file_output
                        t = @deplate.variables['refButton']
                    else
                        t = 'I'
                    end
                else
                    t = @deplate.file_with_suffix(f, '', true)
                end
                acc << format_url(invoker, t, f, i.label, true)
            end
            l = format_label(invoker, :string, [index_entry_label(n)])
            accum << get_index_item(@args, l, plain_text(n), acc)
        end
        accum << get_index_close(@args)
       
        acc = []
        acc << get_index_toc_open(@args)
        for c in chars
            acc << format_url(invoker, c, "", format_index_hd_label(c), true)
        end
        acc << get_index_toc_close(@args)
        acc << join_blocks(accum)
        join_blocks(acc)
    end
    
    def format_index_hd_label(char)
        return "hdIdx#{char}"
    end

    
    ################################################ Particles {{{1
    def get_stacked(args, above, below)
        get_subscript(args, below) + get_superscript(args, above)
    end

end


class Deplate::Element::Heading
    self.label_mode = :after
end

