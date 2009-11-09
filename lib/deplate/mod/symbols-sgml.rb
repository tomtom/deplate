# encoding: ASCII
# symbols-sgml.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     27-Aug-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.49

class Deplate::Symbols::SGML < Deplate::Symbols
    self.myname = :sgml
    
    def symbol_quote(invoker)
        "&#34;" #"&quot;"
    end

    def symbol_gt(invoker)
        "&#62;" #"&gt;"
    end

    def symbol_lt(invoker)
        "&#60;" #"&lt;"
    end

    def symbol_amp(invoker)
        "&#38;" #"&amp;"
    end

    def doublequote_open(invoker)
        "&#8220;" #"&ldquo;"
    end

    def doublequote_close(invoker)
        "&#8221;" #"&rdquo;"
    end

    def singlequote_open(invoker)
        "&#8216;" #"&lsquo;"
    end

    def singlequote_close(invoker)
        "&#8217;" #"&rsquo;"
    end

    def nonbreakingspace(invoker)
        "&#160;" #%{&nbsp;}
    end

    # def symbol_paragraph(invoker)
    #     %{§}
    # end

    def format_symbol(invoker, sym)
        case sym
        when "<-"
            return "&#8592;" #"&larr;"
        when "->"
            return "&#8594;" #"&rarr;"
        when "<=", "<<<"
            return "&#8656;" #"&lArr;"
        when "=>", ">>>"
            return "&#8658;" #"&rArr;"
        when "<->"
            return "&#8596;" #"&harr;"
        when "<=>"
            return "&#8660;" #"&hArr;"
        when "!="
            return "&#8800;" #"&ne;"
        when "~~"
            return "&#8776;" #&asymp;"
        when "..."
            return "&#8230;" #"&hellip;"
        when "--"
            return "&#8211;" #"&ndash;"
        when "=="
            return "&#8801;" #"&equiv;"
        when "+++", "###", "???", "!!!"
            p = @formatter.formatted_inline("para", @formatter.plain_text(sym))
            m = @formatter.formatted_inline("sidebar", p)
            if defined?(invoker.epilogue)
                invoker.epilogue << m
                return ""
            else
                return m
            end
            # when "<~"
            # return ""
            # when "~>"
            # return ""
            # when "<~>"
            # return ""
        else
            super
        end
    end
end

