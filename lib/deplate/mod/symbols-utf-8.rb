# encoding: UTF-8
# symbols-sgml.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     27-Aug-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.41

class Deplate::Symbols::Utf8 < Deplate::Symbols
    self.myname = "utf-8"

    def doublequote_open(invoker)
        %{“}
    end

    def doublequote_close(invoker)
        %{”}
    end

    def singlequote_open(invoker)
        %{‘}
    end

    def singlequote_close(invoker)
        %{’}
    end

    def nonbreakingspace(invoker)
        %{ }
    end

    # def symbol_paragraph(invoker)
    #     %{§}
    # end

    def format_symbol(invoker, sym)
        case sym
        when "<-"
            return "←"
        when "->"
            return "→"
        when "<=", "<<<"
            return "◄"
        when "=>", ">>>"
            return "►"
        when "<->"
            return "↔"
        when "<=>"
            return "◄►"
        when "!="
            return "≠"
        when "~~"
            return "≈"
        when "..."
            return "…"
        when "--"
            return "—"
        when "=="
            return "≡"
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

