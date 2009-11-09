# encoding: ASCII
# endnotes.rb -- display endnotes instead of footnotes
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     20-Aug-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.88


class Deplate::Formatter
    def setup_endnotes
        @deplate.set_slot_name(:footnotes, false)
    end
end

class Deplate::Formatter::LaTeX
    def prepare_endnotes
        output_at(:pre, :mod_packages, "\\usepackage{endnotes}")
        notes = plain_text(@deplate.msg("Notes"))
        if notes != "Notes"
            output_at(:pre, :mod_head, "\\renewcommand{\\notesname}{#{notes}}")
        end
        output_at(:pre, :mod_head, "\\let\\footnote=\\endnote")
    end
    
    def format_list_of_endnotes(invoker)
        join_blocks(["\\newpage", "\\begingroup", 
                    "\\parindent 0pt", "\\parskip 2ex", 
                    "\\def\\enotesize{\\normalsize}", "\\theendnotes", 
                    "\\endgroup"])
    end
    alias format_list_of_footnotes format_list_of_endnotes
end

class Deplate::Formatter::HTML
    def format_list_of_endnotes(invoker)
        title = plain_text(@deplate.msg("Notes"))
        acc   = []
        acc << %{<div class="endnotes"><h1 class="endnotes">%s</h1>} % title
        for l, f in @deplate.footnotes.sort {|a, b| a[1].elt.n <=> b[1].elt.n}
            fn     = f.elt
            idx    = fn.n
            hclass = "sdfootnoteanc"
            id     = "sdfootnote%d"    % idx
            name   = "sdfootnote%danc" % idx
            href   = Deplate::Macro::Footnote::FootnoteTemplate % idx
            t      = [%{<div id="#{id}">},
                %{<p class="sdendnote">}, 
                %{<a class="sdendnotesym" name="#{href}" href="##{name}">#{idx}</a>},
                %{#{fn.body}},
                %{</p></div>}
            ]
            acc << t.join("\n")
        end
        acc << "</div>"
        join_blocks(acc)
    end
    alias format_list_of_footnotes format_list_of_endnotes
end

