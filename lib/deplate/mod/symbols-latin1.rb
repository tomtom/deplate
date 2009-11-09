# encoding: ISO-8859-1
# symbols-latin1.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     27-Aug-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.50

class Deplate::Symbols::Latin1 < Deplate::Symbols
    self.myname = 'ISO-8859-1'
    register_as 'latin1'
    
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
        # %{“}
        %{"}
    end

    def doublequote_close(invoker)
        # %{”}
        %{"}
    end

    def singlequote_open(invoker)
        # %{‘}
        %{'}
    end

    def singlequote_close(invoker)
        # %{’}
        %{'}
    end

    def nonbreakingspace(invoker)
        " " #%{&nbsp;}
    end

end

