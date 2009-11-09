# encoding: ASCII
# dbk-ref.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     17-Mär-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.2130

require "deplate/docbook"

class Deplate::Formatter::DbkRef < Deplate::Formatter::Docbook
    self.myname = "dbk-ref"
    self.rx     = /dbk|dbk-ref|docbook/i
    self.related = ['dbk']

    def initialize(deplate, args)
        @headings = ["refsect1", "refsect2", "refsect3"]
        super
    end

    def setup
        @deplate.variables["headings"]   = "plain"
        @deplate.variables['dbkClass'] ||= 'refentry'
    end

    def get_doc_open(args)
        out = @deplate.variables["refentry"]
        unless out
            out = @deplate.options.out
            out = File.basename(out, '.*')
            @deplate.variables["refentry"] = out
        end
        o = []
        lang = @deplate.options.messages.prop('lang', self)
        if lang
            o << %{ lang="#{lang}"}
        end
        return %{<refentry id="%s"%s>} % [out, o.join]
    end

    def get_doc_close(args)
        return "</refentry>"
    end

    # get_doc_head_open(args)
    noop self, "get_doc_head_open"

    # get_doc_head_close(args)
    noop self, "get_doc_head_close"

    def get_doc_head(args)
        refentry      = @deplate.variables["refentry"]
        refentrytitle = formatted_inline("refentrytitle", refentry)
        manvolnum     = formatted_inline("manvolnum", @deplate.variables["manvol"] || "1")
        refmeta       = formatted_block("refmeta", [refentrytitle, manvolnum].join("\n"))

        refname    = formatted_inline("refname", refentry)
        ti = @deplate.get_clip("title")
        refpurpose = ti ? formatted_inline("refpurpose", ti.elt) : nil
        refnamediv = formatted_block("refnamediv", [refname, refpurpose].join("\n"))

        authors    = @deplate.options.author
        accAuthors = docbook_authors(authors)
        if authors.size > 1
            refauthor = formatted_block("authorgroup", accAuthors.join("\n"))
        else
            refauthor = accAuthors.join("\n")
        end

        dt = @deplate.get_clip("date")
        dt = dt.elt if dt
        date = dt ? formatted_inline("date", dt) : nil

        yr = @deplate.variables["copyrightYear"] || dt
        if yr
            year   = Deplate::Core.split_list(yr, ',', '; ').collect {|yr| formatted_inline("year", yr)}
            holder = @deplate.get_clip("author")
            holder = formatted_inline("holder", holder.elt) if holder
            copyright = formatted_block("copyright", [year, holder].flatten.compact.join("\n"))
        else
            copyright = nil
        end
        
        refentryinfo = [copyright || refauthor, date].compact
        unless refentryinfo.empty?
            refentryinfo = formatted_block("refentryinfo", refentryinfo.join("\n"))
        else
            refentryinfo = nil
        end

        # <refsynopsisdiv>
        # <cmdsynopsis>
        # <command>/usr/bin/ls</command>
        # <arg choice="opt">
          # <option>aAbcCdfFgilLmnopqrRstux1</option>
        # </arg>
        # <arg choice="opt" rep="repeat">file</arg>
        # </cmdsynopsis>
        # </refsynopsisdiv>

        return [refentryinfo, refmeta, refnamediv].join("\n")
    end
    
    noop self, "get_index"
end

