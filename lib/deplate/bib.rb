# encoding: ASCII
# bib.rb
# @Author:      Tom Link (micathom AT gmail com)
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     11-Feb-2006.
# @Last Change: 2009-11-09.
# @Revision:    0.92
#
# = Description
# = Usage
# = TODO
# = CHANGES

require "deplate/common"

module Deplate::Bib; end

class Deplate::Bib::Default < Deplate::CommonObject
    class << self
        # def hook_post_style=(name)
        #     klass = self
        #     Deplate::Core.class_eval {declare_bibstyle(klass, name)}
        # end
        def register_as(*names)
            klass = self
            names.each do |name|
                Deplate::Core.class_eval {declare_bibstyle(klass, name)}
            end
        end
    end

    # class_attribute :style
    # self.style = 'default'
    register_as 'default'
    
    def initialize(deplate)
        @deplate = deplate
    end

    def bib_format(bibdef)
        type = bib_get_value(bibdef, '_type').downcase
        meth = "bib_#{type}"
        unless self.respond_to?(meth, true)
            meth = 'bib_default'
        end
        blocks = send(meth, bibdef)
        bib_join(blocks)
    end

    def bib_cite(invoker)
        container = invoker.container
        args = invoker.args
        n    = args['n']
        p    = args['p']
        ip   = args['ip']
        np   = ip || args['np']
        mode = args['mode']
        y    = args['y']
        sep  = args['sep'] || (np ? '' : ' ')
        acc  = []
        pmsg = @deplate.msg('p.\\ ')
        for c in invoker.elt
            cc = @deplate.formatter.bib_entry(c)
            if cc
                yr = cc['year'] || ''
                if p
                    p = @deplate.parse_and_format_without_wikinames(container, "#{pmsg}#{p}")
                    yr += ": #{p}"
                    # yr  += ": " + p if p
                end
                if y
                    acc << referenced_bib_entry(invoker, c, yr)
                else
                    nm = cc['author'] || cc['editor'] || cc['howpublished']
                    if nm
                        if nm =~ /^\{(.*?)\}$/
                            nm = $1
                        else
                            nm = nm.gsub(/\s+/, ' ').split(/ +and +/).collect do |a|
                                a.scan(/[^[:space:][:cntrl:]]+$/)
                            end
                            nm   = nm.join(', ')
                        end
                        if ip
                            acc << referenced_bib_entry(invoker, c, "#{nm} (#{yr})")
                        else
                            acc << referenced_bib_entry(invoker, c, [nm, yr].join(' '))
                        end
                    else
                        acc << referenced_bib_entry(invoker, c, c)
                    end
                end
            end
        end
        n &&= n + @deplate.formatter.plain_text(' ', true)
        acc = acc.join('; ')
        sep = @deplate.formatter.plain_text(sep, true)
        if np
            return %{#{sep}#{n}#{acc}}
        else
            case mode
            when 'np'
                return %{#{sep}#{n}#{acc}}
            else
                return %{#{sep}(#{n}#{acc})}
            end
        end
    end

    private
    def referenced_bib_entry(invoker, key, text)
        if @deplate.variables['noBibClickableCitation']
            text
        else
            @deplate.formatter.referenced_bib_entry(invoker, key, text)
        end
    end
    
    def bib_get_value(bibdef, key)
        val = bibdef[key.downcase]
        if val
            val.gsub(/\s{2,}/, ' ')
        end
    end

    def bib_join(bibblocks)
        bibblocks.compact.join(' ')
    end

    def bib_block(*blocks)
        if blocks
            b = blocks.compact.join(' ').chomp
            if b[-1..-1] !~ /[.!?]['"]?$/
                b << '.'
            end
            b
        end
    end

    def bib_inblock(*blocks)
        if blocks
            blocks.compact.join(', ').chomp
        end
    end
 
    def bib_emphasize_title(text)
        Deplate::Particle::Emphasize.markup(text)
    end

    def bib_default(bibdef)
        authorship = bib_author(bibdef) || bib_editor(bibdef) || bib_institution(bibdef)
        year       = bib_year(bibdef)
        title      = bib_title(bibdef) || bib_booktitle(bibdef)
        howpub     = bib_journal(bibdef) || bib_publisher(bibdef) || 
            bib_institution(bibdef) || bib_howpublished(bibdef) || 
            bib_address(bibdef)
        url        = bib_url(bibdef)
        [bib_block(authorship, year), 
            bib_block(bib_emphasize_title(title)), 
            bib_block(howpub),
            url]
    end

    # author title journal year
    # volume number month pages
    def bib_article(bibdef)
        author  = bib_author(bibdef)
        year    = bib_year(bibdef)
        title   = bib_title(bibdef)
        journal = bib_journal(bibdef)
        volume  = bib_volume(bibdef)
        number  = bib_number(bibdef)
        month   = bib_month(bibdef)
        pages   = bib_pages(bibdef)
        url     = bib_url(bibdef)
        vol     = if volume
                      if number
                          "#{volume}(#{number})"
                      else
                          volume
                      end
                  elsif month
                      @deplate.msg(month)
                  end
        vol     = if pages
                      if vol
                          "#{vol}:#{pages}"
                      else
                          pages
                      end
                  end
        [bib_block(author, year), 
            bib_block(title), 
            bib_block(bib_emphasize_title(journal), vol),
            url]
    end

    # author editor title booktitle publisher year      
    # volume number month series edition address   
    def bib_book(bibdef)
        author  = bib_author(bibdef) || bib_editor(bibdef)
        year    = bib_year(bibdef)
        title   = bib_title(bibdef) || bib_booktitle(bibdef)
        pub     = bib_publisher(bibdef)
        volume  = bib_volume(bibdef)
        number  = bib_number(bibdef)
        month   = bib_month(bibdef)
        series  = bib_series(bibdef)
        edition = bib_edition(bibdef)
        address = bib_address(bibdef)
        url     = bib_url(bibdef)
        # [author, year, title, edition, pub, series]
        [bib_block(author, year), 
            bib_block(bib_emphasize_title(title)), 
            bib_block(bib_inblock(pub, series)),
            url]
    end

    # editor booktitle publisher year
    # volume number month series edition address
    def bib_book_collection(bibdef)
        author  = bib_editor(bibdef)
        year    = bib_year(bibdef)
        title   = bib_booktitle(bibdef)
        pub     = bib_publisher(bibdef)
        volume  = bib_volume(bibdef)
        number  = bib_number(bibdef)
        month   = bib_month(bibdef)
        series  = bib_series(bibdef)
        edition = bib_edition(bibdef)
        address = bib_address(bibdef)
        url     = bib_url(bibdef)
        # [author, year, title, edition, pub, series]
        [bib_block(author, year), 
            bib_block(bib_emphasize_title(title)), 
            bib_block(bib_inblock(pub, series)),
            url]
    end

    # title
    # author howpublished address month year
    def bib_booklet(bibdef)
        author  = bib_editor(bibdef)
        year    = bib_year(bibdef)
        title   = bib_booktitle(bibdef)
        how     = bib_howpublished(bibdef)
        month   = bib_month(bibdef)
        address = bib_address(bibdef)
        url     = bib_url(bibdef)
        [bib_block(author, year), 
            bib_block(bib_emphasize_title(title)), 
            bib_block(bib_inblock(how, address)),
            url]
    end

    # author title crossref pages chapter
    # def bib_conference(bibdef)
    #     # <+TBD+>
    # end

    # author editor title chapter pages publisher year
    # volume number month series edition address
    def bib_inbook(bibdef)
        author  = bib_author(bibdef) || bib_editor(bibdef)
        year    = bib_year(bibdef)
        title   = bib_title(bibdef) || bib_booktitle(bibdef)
        where   = bib_chapter(bibdef)
        pages   = bib_pages(bibdef)
        pub     = bib_publisher(bibdef)
        volume  = bib_volume(bibdef)
        number  = bib_number(bibdef)
        month   = bib_month(bibdef)
        series  = bib_series(bibdef)
        edition = bib_edition(bibdef)
        address = bib_address(bibdef)
        url     = bib_url(bibdef)
        [bib_block(author, year), 
            bib_block(bib_inblock(chapter, pages)), 
            bib_block(@deplate.msg('In:'), bib_emphasize_title(title)), 
            bib_block(bib_inblock(pub, series)),
            url]
    end

    # author title crossref pages chapter
    def bib_incollection(bibdef)
        author  = bib_author(bibdef)
        editor  = bib_editor(bibdef)
        year    = bib_year(bibdef)
        title   = bib_title(bibdef)
        book    = bib_booktitle(bibdef)
        chapter = bib_chapter(bibdef)
        pages   = bib_pages(bibdef)
        pages &&= [@deplate.msg('p.\\ '), pages].join
        pub     = bib_publisher(bibdef)
        volume  = bib_volume(bibdef)
        number  = bib_number(bibdef)
        month   = bib_month(bibdef)
        series  = bib_series(bibdef)
        edition = bib_edition(bibdef)
        address = bib_address(bibdef)
        url     = bib_url(bibdef)
        [bib_block(author, year), 
            bib_block(title), 
            bib_block([@deplate.msg('In:'), editor].join(' ')),
            bib_block(bib_emphasize_title(book)),
            bib_block(bib_inblock(pub, series)), 
            bib_block(bib_inblock(chapter, pages)),
            url]
    end

    # author title crossref pages chapter
    def bib_inproceedings(bibdef)
        # <+TBD+>
        bib_inbook(bibdef)
    end

    # title
    # author organization address edition month year
    def bib_manual(bibdef)
        author  = bib_author(bibdef) || bib_organization(bibdef)
        year    = bib_year(bibdef)
        title   = bib_title(bibdef)
        how     = bib_organization(bibdef)
        month   = bib_month(bibdef)
        address = bib_address(bibdef)
        url     = bib_url(bibdef)
        [bib_block(author, year), 
            bib_block(bib_emphasize_title(title)), 
            bib_block(bib_inblock(how, address)),
            url]
    end
    
    # author title school year    
    # type address month   
    def bib_masterthesis(bibdef)
        author  = bib_author(bibdef)
        year    = bib_year(bibdef)
        title   = bib_title(bibdef)
        how     = bib_school(bibdef)
        month   = bib_month(bibdef)
        address = bib_address(bibdef)
        url     = bib_url(bibdef)
        [bib_block(author, year), 
            bib_block(bib_emphasize_title(title)), 
            bib_block(bib_inblock(how, address)), 
            url]
    end

    # author title howpublished month year             
    def bib_misc(bibdef)
        author  = bib_author(bibdef)
        how     = bib_howpublished(bibdef)
        pub     = bib_publisher(bibdef)
        if !author and how
            author = how
            how = nil
        end
        if !how and pub
            how = pub
        end
        year    = bib_year(bibdef)
        title   = bib_title(bibdef)
        month   = bib_month(bibdef)
        address = bib_address(bibdef)
        url     = bib_url(bibdef)
        [bib_block(author, year), 
            bib_block(bib_emphasize_title(title)), 
            bib_block(bib_inblock(how, address)),
            url]
    end

    # author title school year
    # type address month   
    def bib_phdthesis(bibdef)
        author  = bib_author(bibdef)
        year    = bib_year(bibdef)
        title   = bib_booktitle(bibdef)
        how     = bib_school(bibdef)
        month   = bib_month(bibdef)
        address = bib_address(bibdef)
        type    = bib_type(bibdef)
        url     = bib_url(bibdef)
        [bib_block(author, year), 
            bib_block(bib_inblock(bib_emphasize_title(title), type)), 
            bib_block(bib_inblock(how, address)),
            url]
    end

    # title year
    # editor volume number series address month organization publisher
    def bib_proceedings(bibdef)
        author  = bib_editor(bibdef) || bib_organization(bibdef)
        year    = bib_year(bibdef)
        title   = bib_booktitle(bibdef)
        volume  = bib_volume(bibdef)
        number  = bib_number(bibdef)
        month   = bib_month(bibdef)
        series  = bib_series(bibdef)
        address = bib_address(bibdef)
        pub     = bib_publisher(bibdef)
        url     = bib_url(bibdef)
        [bib_block(author, year), 
            bib_block(bib_emphasize_title(title)), 
            bib_block(bib_inblock(pub, series, address)),
            url]
    end
    
    # author title institution year
    # type number address month 
    def bib_techreport(bibdef)
        author  = bib_author(bibdef) || bib_institution(bibdef)
        year    = bib_year(bibdef)
        title   = bib_title(bibdef)
        how     = bib_institution(bibdef)
        pub     = bib_publisher(bibdef)
        type    = bib_type(bibdef)
        number  = bib_number(bibdef)
        month   = bib_month(bibdef)
        address = bib_address(bibdef)
        url     = bib_url(bibdef)
        [bib_block(author, year), 
            bib_block(bib_inblock(bib_emphasize_title(title), type)), 
            bib_block(how), 
            bib_block(bib_inblock(pub, address)),
            url]
    end

    # author title note
    # month year
    def bib_unpublished(bibdef)
        author  = bib_author(bibdef)
        year    = bib_year(bibdef)
        title   = bib_booktitle(bibdef)
        note    = bib_note(bibdef)
        month   = bib_month(bibdef)
        url     = bib_url(bibdef)
        [bib_block(author, year), 
            bib_block(bib_emphasize_title(title)), 
            bib_block(note),
            url]
    end

    def bib_address(bibdef)
        bib_get_value(bibdef, 'address')
    end

    def bib_author(bibdef)
        au = bib_get_value(bibdef, 'author')
        if au
            reformat_authors(au)
        end
    end

    def bib_booktitle(bibdef)
        bib_get_value(bibdef, 'booktitle')
    end

    def bib_chapter(bibdef)
        ch = bib_get_value(bibdef, 'chapter')
        [@deplate.msg('Chapter'), ch].join(' ') if ch
    end

    def bib_edition(bibdef)
        ed = bib_get_value(bibdef, 'edition')
        [ed, @deplate.msg('Edition')].join(' ') if ed
    end

    def bib_editor(bibdef)
        ed = bib_get_value(bibdef, 'editor')
        if ed
            ed = reformat_editors(ed)
            [ed, '\\ (', @deplate.msg('Ed.'), ')'].join
        end
    end

    def bib_howpublished(bibdef)
        bib_get_value(bibdef, 'howpublished')
    end

    def bib_institution(bibdef)
        bib_get_value(bibdef, 'institution')
    end

    def bib_journal(bibdef)
        bib_get_value(bibdef, 'journal')
    end

    def bib_key(bibdef)
        bib_get_value(bibdef, 'key')
    end

    def bib_keywords(bibdef)
        bib_get_value(bibdef, 'keywords')
    end

    def bib_month(bibdef)
        mo = bib_get_value(bibdef, 'month')
        mo ? @deplate.msg(mo) : nil
    end

    def bib_note(bibdef)
        bib_get_value(bibdef, 'note')
    end

    def bib_number(bibdef)
        bib_get_value(bibdef, 'number')
    end

    def bib_organization(bibdef)
        bib_get_value(bibdef, 'organization')
    end

    def bib_pages(bibdef)
        bib_get_value(bibdef, 'pages')
    end

    def bib_publisher(bibdef)
        bib_get_value(bibdef, 'publisher')
    end

    def bib_school(bibdef)
        bib_get_value(bibdef, 'school')
    end

    def bib_series(bibdef)
        bib_get_value(bibdef, 'series')
    end

    def bib_title(bibdef)
        bib_get_value(bibdef, 'title')
    end

    def bib_type(bibdef)
        bib_get_value(bibdef, 'type')
    end

    def bib_url(bibdef)
        url  = bib_get_value(bibdef, 'url')
        date = bib_get_value(bibdef, 'access')
        msg  = date ? 'Available online at (%s):' : 'Available online at:'
        [@deplate.msg(msg), url].join(' ') if url
    end

    def bib_volume(bibdef)
        bib_get_value(bibdef, 'volume')
    end

    def bib_year(bibdef)
        y = bib_get_value(bibdef, 'year')
        ['(', y, ')'].join if y
    end

    def reformat_authors(text)
        if text
			if text =~ /^\{(.*?)\}$/
				return $1
			else
				namesep   = @deplate.variables['bibSepName'] || bibSepName
				authorsep = @deplate.variables['bibSepAuthors'] || bibSepAuthors
				twosep    = @deplate.variables['bibSepTwoAuthors'] || bibSepTwoAuthors
				lastsep   = @deplate.variables['bibSepLastAuthor'] || bibSepLastAuthor
				authors   = Deplate::Core.authors_split(text)
				authorsn  = authors.size
				authorsn1 = authors.size - 1
				authorsn2 = authors.size - 2
				au = []
				authors.each_with_index do |a, i|
					m = /^(.+?)\s*,\s*(.+)$/.match(a.strip)
                    if m
                        au << reformat_author_name(m[2], m[1], namesep)
                    else
                        m = /^((.+?)?\s+)?(\S+)$/.match(a.strip)
                        if m[2]
                            au << reformat_author_name(m[2], m[3], namesep)
                        else
                            au << a
                        end
                        if i < authorsn2
                            au << authorsep
                        elsif i < authorsn1
                            au << (authorsn == 2 ? twosep : lastsep)
                        end
                    end
				end
				return au.join
			end
        end
    end

    alias :reformat_editors :reformat_authors

    def reformat_author_name(firstname, name, sep)
        [name, sep, firstname].join
    end

    def bibSepName
        ', '
    end

    def bibSepAuthors
        '; '
    end
    
    alias :bibSepTwoAuthors :bibSepAuthors
    alias :bibSepLastAuthor :bibSepAuthors
    
end

