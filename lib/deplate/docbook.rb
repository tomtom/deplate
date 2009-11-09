# encoding: ASCII
# docbook.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     17-Mär-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.2760

require 'deplate/xml'

# An abstract docbook formatter

class Deplate::Formatter::Docbook < Deplate::Formatter::XML
    def initialize(deplate, args)
        @sgml         = false
        super
    end

    def get_open(tag, opts=nil, args=nil, other_args={})
        single = other_args[:single] || false
        no_id  = other_args[:no_id] || false
        opts ||= {}
        args ||= {}
        unless no_id
            id  = use_id(args, opts)
            oid = opts['id']
            if oid and oid != id
                log(['ID mismatch', id, oid, opts, args], :error)
            end
            opts['id'] = encode_id(id) if id
            # args = args.dup
            args.delete('id')
        end
        id = opts['id']
        if id
            if consumed_ids.include?(id)
                opts = opts.dup
                opts.delete('id')
            else
               consumed_ids << id
            end
            opts['xreflabel'] ||= args[:level_as_string]
        end
        opts = opts.collect do |k, v|
            case k
            when 'linkend'
                v = encode_id(v)
            end
            if v
                %{%s="%s"} % [k, v]
            end
        end
        if single
            if @sgml
                opts << '></%s' % tag
            else
                opts << '/'
            end
        end
        %{<%s>} % [tag, *opts].compact.join(' ')
    end
   
    def get_close(tag, args=nil)
        %{</%s>} % tag
    end

    def get_emphasize(args, text)
        formatted_inline('emphasis', text)
    end
    
    def get_code(args, text)
        formatted_inline('literal', text)
    end
        
    def get_url(args, name, dest, anchor, literal=false)
        formatted_inline('ulink', name, {'url' => dest.gsub(/&/, '&amp;')})
    end
        
    def get_wiki(args, name, dest, anchor)
        formatted_inline('ulink', name, {'url' => dest})
    end
        
    def docbook_authors(authors)
        accAuthors = []
        for au in authors
            acc = []
            author = []
            if au[:firstname] and au[:surname]
                firstname = @deplate.parse_and_format(nil, au[:firstname], false)
                author << formatted_inline('firstname', firstname)
                surname = @deplate.parse_and_format(nil, au[:surname], false)
                author << formatted_inline('surname', surname)
            else
                surname = @deplate.parse_and_format(nil, au[:name], false)
                author << formatted_inline('surname', surname)
            end
            acc << author.join
            if au[:note]
                authorblurb = @deplate.parse_and_format(nil, au[:note], false)
                acc << formatted_block('authorblurb', formatted_inline('para', authorblurb))
            end
            accAuthors << formatted_block('author', join_blocks(acc))
        end
        return accAuthors
    end
    
    def get_doc_head(args)
        accum      = []
        
        authors    = @deplate.options.author || []
        accAuthors = docbook_authors(authors)
        if authors.size > 1
            accum << formatted_block('authorgroup', join_blocks(accAuthors))
        else
            accum += accAuthors
        end
        
        date = @deplate.get_clip('date')
        date = date ? date.elt : Deplate::Element.get_date('today', nil)
        accum << formatted_inline('pubdate', date)
        
        title = @deplate.get_clip('title')
        accum << formatted_inline('title', title.elt) if title
        
        kw = keywords
        if kw
            kws = join_blocks(kw.collect {|kw| formatted_inline('keyword', kw)})
            accum << formatted_block('keywordset', kws)
        end
        
        desc = @deplate.variables['description']
        if desc
            para = formatted_inline('para', plain_text(desc))
            accum << formatted_block('abstract', para)
        end
            
        return join_blocks(accum)
    end

    def get_doc_def(args)
        version = @deplate.variables['dbkVersion'] || '4.2'
        type    = @deplate.variables['dbkClass']   || 'article'
        oldnew  = @sgml ? 'sgml' : 'xml'
        dbkid   = @deplate.variables['dbkId']      || "-//OASIS//DTD DocBook XML V#{version}//EN"
        dtd     = @deplate.variables['dbkDtd']     || "http://www.oasis-open.org/docbook/#{oldnew}/#{version}/docbookx.dtd"
        docbook_doc_def(args, type, dbkid, dtd)
    end

    def docbook_doc_def(args, type, pub, dtd, xmlVersion='1.0')
        encoding = @encoding ? %{ encoding="%s"} % @encoding : ""

        doc = [%{<?xml version='#{xmlVersion}'#{encoding}?>},
            %{<!DOCTYPE #{type} PUBLIC "#{pub}"},
            %{    "#{dtd}"}
        ]
        ent = get_entities(args)
        if ent
            doc.last << ' ['
            doc << ent << ']'
        end
        doc.last << '>'
        return join_blocks(doc.flatten.compact)
    end
   
    def get_entities(args)
        entities = args[:deplate].variables['dbkEntities']
        return join_blocks(entities) if entities
    end

    def get_entity(id, pub)
        %{<!ENTITY %% %s PUBLIC "%s">\n%%%s;} % [id, pub, id]
    end

    # get_doc_body_open(args)
    noop self, 'get_doc_body_open'

    # get_doc_body_close(args)
    noop self, 'get_doc_body_close'

    # Bibliography
    def get_bib(args, title, bib)
        acc = [close_headings(1)]
        title = formatted_inline('title', title) if title and !args['plain']
        acc << formatted_block('bibliography', join_blocks([title, bib].compact), nil, args)
        join_blocks(acc)
    end

    def get_bib_entry(args, key, entry)
        body = join_blocks([formatted_inline('abbrev', key), entry])
        return formatted_block('biblioentry', body, {'id' => encode_id(key)}, args)
    end

    def docbook_format_authors(type, args, text)
        if text
            acc = []
            for au in Deplate::Core.authors_split(text)
                if (author = Deplate::Names.name_match_c(au))
                    acc << formatted_inline(type, formatted_inline('surname', author[:surname]))
                elsif (author = Deplate::Names.name_match_sf(au) || Deplate::Names.name_match_fs(au))
                    surname   = formatted_inline('surname', author[:surname])
                    firstname = formatted_inline('firstname', author[:firstname])
                    acc << formatted_inline(type, surname + firstname)
                else
                    # is this ok???
                    acc << formatted_inline(type, formatted_inline('surname', au))
                end
            end
            if acc.size > 1
                return formatted_block('authorgroup', join_blocks(acc), nil, args)
            else
                return join_blocks(acc)
            end
        end
    end
    
    def get_bib_author(args, text)
        docbook_format_authors('author', args, text)
    end
    
    def get_bib_year(args, text)
        formatted_inline('pubdate', text)
    end

    def get_bib_booktitle(args, text)
        formatted_inline('title', text)
    end

    def get_bib_editor(args, text)
        docbook_format_authors('editor', args, text)
    end

    def get_bib_journal(args, text)
        formatted_inline('title', text)
    end

    def get_bib_pages(args, text)
        formatted_inline('pagenums', text)
    end

    def get_bib_publisher(args, text)
        formatted_block('publisher', formatted_inline('publishername', text), nil, args)
    end

    def get_bib_title(args, text)
        formatted_inline('title', text)
    end

    def get_bib_volume(args, text)
        formatted_inline('volumenum', text)
    end

    def get_bib_number(args, text)
        formatted_inline('issuenum', text)
    end

    def docbook_bib_sorted_values(entry)
        keys = ['author', 'title', 'editor', 'booktitle', 'publisher', 'journal', 'volume', 'number', 'pages', 'year']
        entry = entry.sort {|a, b| keys.index(a[0]) <=> keys.index(b[0])}
        entry.collect {|a| a[1..-1]}.flatten
    end

    def docbook_bib_relation(args, typeEntry, entry, typeContainer, container)
        e = join_blocks(docbook_bib_sorted_values(entry))
        e = formatted_block('biblioset', e, {'relation' => typeEntry}, args)
        c = join_blocks(docbook_bib_sorted_values(container))
        c = formatted_block('biblioset', c, {'relation' => typeContainer}, args)
        return join_blocks([e, c])
    end
    
    def get_bib_relation(args, type, entry, container)
        if type
            case type.downcase
            when 'article'
                return docbook_bib_relation(args, 'article', entry, 'journal', container)
            when 'incollection'
                # is this ok???
                return docbook_bib_relation(args, 'article', entry, 'book', container)
            end
        else
            args[:self].log(['No bib entry type given', entry], :error)
        end
        join_blocks(docbook_bib_sorted_values(entry.update(container)))
    end
    

    # Text
    def get_block_abstract(args, text)
        return formatted_block('abstract', text, nil, args)
    end

    def get_block_longquote(args, text)
        return formatted_block('blockquote', text, nil, args)
    end

    def get_block_quote(args, text)
        return formatted_block('blockquote', text, nil, args)
    end

    def get_note(args, marker, text)
        case marker
        when '#'
            tag = 'note'
        when '+'
            tag = 'warning'
        when '?'
            tag = 'caution'
        when '!'
            tag = 'important'
        else
            log(['Unknown marker', marker], :error)
            tag = 'note'
        end
        return formatted_block(tag, formatted_inline('para', text), nil, args)
    end
    
    def get_pre_format(args, text)
        return formatted_block('screen', %{<![CDATA[#{text}]]>}, nil, args, false, true)
    end

    # Lists, Contents
    # get_contents_open(args, prefix)
    noop self, 'get_contents_open'
    # get_contents_close(args, prefix)
    noop self, 'get_contents_close'
    # get_contents_list(args, prefix, list)
    noop self, 'get_contents_list'
   
    # get_list_of_tables(args, data)
    noop self, 'get_list_of_tables'
    # get_list_of_figures(args, data)
    noop self, 'get_list_of_figures'

    def listing_prematter(invoker, args, id)
        case args[:listing]
        when 'toc'
            get_open('lot', {:id => id}, args)
        else
            args[:id] ||= id
            get_list_itemize_open(args)
        end
    end
    
    def listing_postmatter(invoker, args)
        case args[:listing]
        when 'toc'
            get_close('lot')
        else
            get_list_itemize_close(args)
        end
    end
    
    def listing_title(invoker, args, name)
        if name
            # case args[:listing]
            # when 'toc'
                formatted_inline('title', @deplate.msg(name))
            # else
            # end
        end
    end
    
    def listing_item(invoker, args, prefix, title, heading, level, other_args)
        v = clean_tags(title)
        # v = clean_tags(title, 'indexterm')
        case other_args[:listing]
        when 'toc'
            v = [heading.level_as_string, v].join(' ') unless heading.plain_caption?
            d = @deplate.elt_label(prefix, heading.level_as_string)
            f = formatted_inline('lotentry', v, {'linkend' => d})
            s = Deplate::ListItem.new(nil, nil, nil, nil, level, 0, true)
            s.preformatted = [f, nil]
        else
            v = [heading.level_as_string, v].join(' ') unless heading.plain_caption?
            d = @deplate.elt_label(prefix, heading.level_as_string)
            s = Deplate::ListItem.new(nil, nil, nil, nil, level, 0, true)
            f = join_blocks([
                get_item_itemize_open(args, heading.level_as_string, v),
                get_item_itemize_close(args)
            ])
            s.preformatted = [f, nil]
        end
        s
    end

    def get_item_paragraph(args, item, text)
        formatted_inline('para', text)
    end

    def get_list_description_open(args)
        get_open('variablelist', nil, args)
    end

    def get_list_description_close(args)
        get_close('variablelist', args)
    end

    def get_item_description_open(args, item, text)
        text = indent_text(formatted_inline('para', text))
        list = get_open('varlistentry', nil, args, :no_id => true)
        term = formatted_inline('term', item, nil, args, true)
        item = get_open('listitem', nil, args, :no_id => true)
        idt  = format_indent(1)
        join_blocks([list, idt + term, idt + item, text])
    end

    def get_item_description_close(args)
        idt = format_indent(1)
        join_blocks([idt + get_close('listitem'), get_close('varlistentry')])
    end

    # tasks
    def get_list_task_open(args)
        get_list_description_open(args)
    end

    def get_list_task_close(args)
        get_list_description_close(args)
    end

    def get_item_task_open(args, item, text, opts)
        pri  = opts[:priority]
        cat  = opts[:category]
        done = opts[:done] ? 'done' : nil
        due  = opts[:due]
        task = [cat, pri]
        task << " #{due}" if due
        # task = ['{', task, '}'].join
        task = task.join
        get_item_description_open(args, task, text)
    end
    
    def get_item_task_close(args)
        get_item_description_close(args)
    end

    # itemize
    def get_list_itemize_open(args)
        get_open('itemizedlist', nil, args)
    end

    def get_list_itemize_close(args)
        get_close('itemizedlist')
    end

    def get_item_itemize_open(args, item, text)
        item = get_open('listitem', nil, args, :no_id => true)
        join_blocks([item, indent_text(formatted_inline('para', text))])
    end

    def get_item_itemize_close(args)
        get_close('listitem')
    end

    # numbered
    def get_list_numbered_open(args, subtype)
        opts = {}
        case subtype
        when 'a'
            opts['numeration'] = 'loweralpha'
        when 'A'
            opts['numeration'] = 'upperalpha'
        # when '1'
            # num = 'arabic'
        # else
            # num = 'arabic'
        end
        get_open('orderedlist', opts, args)
    end

    def get_list_numbered_close(args)
        get_close('orderedlist')
    end

    ### +++ explicitely numbered lists +++
    def get_item_numbered_open(args, item, text)
        item = get_open('listitem', nil, args, :no_id => true)
        join_blocks([item, indent_text(formatted_inline('para', text))])
    end

    def get_item_numbered_close(args)
        get_close('listitem')
    end


    # Textstyles
    def get_subscript(args, text)
        formatted_inline('subscript', text)
    end

    def get_superscript(args, text)
        formatted_inline('superscript', text)
    end

    # def get_stacked(args, above, below)
        # +++
    # end


    # Figures
    def get_figure_caption(args, title, text, capAbove)
        formatted_inline('title', text)
    end

    def get_figure(args, cap, img)
        if cap
            formatted_block('figure', join_blocks([cap, img]), nil, args)
        else
            formatted_block('informalfigure', img, nil, args)
        end
    end

    def get_image(args, file, fnroot, inline=false)
        if file =~ Deplate::HyperLink::Url.rx
            Deplate::Core.log([%{Cannot include remote images in current document}, file], :error)
            file = File.basename(file)
        end
        o = {}
        w = args['w'] || args['width']
        # h = args['h'] || args['heigth']
        unless w
            ifile = Deplate::Core.file_join(@deplate.options.dir, file)
            desc  = Deplate::External.image_dimension(ifile)
            w, h, bx, by = desc[:bw]
        end
        o['width'] = w if w
        # o << %{height='#{h}'} if h
        o['fileref'] = file
        img = formatted_block('imageobject', formatted_single('imagedata', o))
        acc = [img]
        alt = args['alt']
        if alt
            acc << formatted_inline('textobject', formatted_inline('phrase', plain_text(alt)))
        end
        img = join_blocks(acc)
        if inline
            formatted_block('inlinemediaobject', img, nil, args)
        else
            formatted_block('mediaobject', img, nil, args)
        end
    end

    def image_suffixes
        ['.png', '.jpeg', '.jpg', '.gif', '.bmp']
    end


    # Header, Footer
    # get_footer(args, text)
    noop self, 'get_footer'
    # get_header(args, text)
    noop self, 'get_header'

    # Footnote
    def get_footnote(args, label, text)
        # formatted_block('footnote', formatted_inline('para', text), {'id'=>label}, args)
        formatted_block('footnote', text, {'id'=>label}, args)
    end

    def get_footnote_ref(args, label, text)
        formatted_single('footnoteref', {'linkend' => label})
    end


    # Sections, Headings
    def get_heading_open(args, level, numbering, text, label)
        hd = @headings[level - 1]
        id = encode_id(args[:id])
        if hd
            plain = @deplate.variables['headings'] == 'plain' || args['plain']
            no_id = id.empty?
            if no_id or plain
                id = encode_id(args['shortcaption'] || text)
                if no_id
                    args[:id] = id if no_id
                    args[:self].log(['Internal error: No ID', @args[:self].class, text, label], :error)
                end
            end
            ho       = {}
            # ho['id'] = id unless id.empty?
            ho['id'] = id
            if plain
                xreflabel       = id
                ho['xreflabel'] = xreflabel
            else
                xlab           = args[:level_as_string]
                if xlab
                    ho['label']     = xlab.split(/\./).last
                    # ho['label']     = args[:level_as_string]
                    xreflabel       = encode_id(xlab)
                    ho['xreflabel'] = xreflabel
                else
                    args[:self].log(['Internal error', 'No label'], :error)
                end
            end
            hd = get_open(hd, ho, args)
            # unless id.empty?
                to = {'id' => "#{id}_title"}
                to['xreflabel'] = xreflabel
            # end
            ti = formatted_inline('title', text, to, args)
            return join_blocks([hd, indent_text(ti), indent_text(label)])
        else
            label << id unless id.empty?
            get_paragraph(args, text, label)
        end
    end

    def get_heading_close(args, level)
        hd = @headings[level - 1]
        if hd
            get_close(hd)
        end
    end


    # Index
    def get_index(args, id, text)
        prim = formatted_inline("primary", text)
        formatted_inline("indexterm", prim, {"id" => encode_id(id)}, args)
    end

    def get_list_of_index(args, data)
        join_blocks([close_headings(1), formatted_single("index", nil, args)])
    end
    
    # get_index_open(args)
    noop self, :get_index_open

    # get_index_close(args)
    noop self, :get_index_close

    # get_index_group_open(args)
    noop self, :get_index_group_open

    # get_index_group_close(args)
    noop self, :get_index_group_close

    # get_index_item(args, labels, text, references)
    noop self, :get_index_item

    # get_index_toc_open(args)
    noop self, :get_index_toc_open

    # get_index_toc_close(args)
    noop self, :get_index_toc_close

    # get_index_toc_entry(args, char, label)
    noop self, :get_index_toc_entry


    # Labels, References
    def get_label(args, label, mode, text='')
        case mode
        when :after, :closeOpen
            text
        else
            join_inline([formatted_single('anchor', {'id' => encode_id(label)}), text])
        end
    end

    def get_ref(args, file, label, heading=nil)
        if label
            if file.empty? and heading
                if @sgml
                    o = @deplate.label_aliases[label]
                    text = o.args[:level_as_string]
                    formatted_inline('link', text, {'linkend' => label}, args)
                else
                    opts = {'linkend' => encode_id(label), 'endterm' => "#{heading}_title"}
                    return formatted_single('xref', opts, args)
                end
            else
                url = [file, label].join('#')
                return formatted_inline('ulink', text, {'url' => 'file://%s' % url}, args)
            end
        else
            args[:self].log('No label', :error)
            return ''
        end
    end


    # Paragraphs, Linebreaks, Pagebreaks
    def get_linebreak(args, container)
        case container.class
        when Deplate::Element::Paragraph
            # well
            %{</para><para>}
        else
            log(["Don't know how to insert linebreaks", container.class], :error)
            ''
        end
    end

    def get_pagebreak(args)
        formatted_single('beginpage', nil, args)
    end

    def get_paragraph(args, text, labels=[])
        acc = []
        for l in use_labels(args, labels)
            acc << get_label(args, l, :string)
        end
        acc << text
        text = join_blocks(acc)
        return formatted_inline('para', text, nil, args)
    end


    # Table
    def get_table(args, title, table)
        opts  = {}
        frame = args['frame'] || @deplate.variables['tableFrame'] || 'topbot'
        if frame
            opts['frame'] = frame
        end
        if title
            formatted_block('table', join_blocks([title, table]), opts, args)
        else
            formatted_block('informaltable', table, opts, args)
        end
    end
    
    def get_table_order
        ['head', 'foot', 'body']
    end
    
    def get_table_caption(args, title, text, capAbove)
        formatted_inline('title', text)
    end

    def get_table_group_open(args, n)
        acc = [get_open('tgroup', {'cols' => n}, args, :no_id => true)]
        
        colwidths = Deplate::Core.props(args['cols'], 'w')
        coljusts  = Deplate::Core.props(args['cols'], 'j')
        names     = []
        for i in 0 .. n - 1
            col = {}

            name = "c#{i}"
            col['colname'] = name
            names << name

            w = colwidths[i]
            if w and !w.empty?
                col['colwidth'] = w
            end
            
            j = coljusts[i]
            if j and !j.empty?
                col['align'] = j
            end
            acc << formatted_single('colspec', col, args, true)
        end
        args[:colnames] = names
        join_blocks(acc)
    end

    def get_table_group_close(args)
        get_close('tgroup')
    end

    def get_table_head_open(args)
        get_open('thead', nil, args, :no_id => true)
    end

    def get_table_head_close(args)
        get_close('thead')
    end

    def get_table_foot_open(args)
        get_open('tfoot', nil, args, :no_id => true)
    end

    def get_table_foot_close(args)
        get_close('tfoot')
    end

    def get_table_body_open(args)
        get_open('tbody', nil, args, :no_id => true)
    end

    def get_table_body_close(args)
        get_close('tbody')
    end

    def get_table_head_cell(args, text, rown, coln, span_x=1, span_y=1)
        entry_args = {}
        if span_y > 1
            entry_args['morerows'] = span_y - 1
        end
        formatted_block('entry', formatted_inline('para', text), entry_args)
    end

    def get_table_cell(args, text, rown, coln, span_x=1, span_y=1)
        entry_args = {}
        if span_y > 1
            entry_args['morerows'] = span_y - 1
        end
        if span_x > 1
            start = args[:colnames][coln]
            entry_args['namest']  = start
            entry_args['nameend'] = args[:colnames][coln + span_x - 1]
        end
        formatted_block('entry', formatted_inline('para', text), entry_args)
    end

    def get_table_note(args, note)
        formatted_inline('para', note)
    end
    
    def get_table_row_open(args)
        get_open('row', nil, args, :no_id => true)
    end

    def get_table_row_close(args)
        get_close('row')
    end


    # Title
    noop self, 'format_title'
    # get_title(args, data, pagebreak)
    noop self, 'get_title'
    # get_title_author(args, text)
    noop self, 'get_title_author'
    # get_title_authornote(args, text)
    noop self, 'get_title_authornote'
    # get_title_date(args, text)
    noop self, 'get_title_date'
    # get_title_title(args, text)
    noop self, 'get_title_title'
end

