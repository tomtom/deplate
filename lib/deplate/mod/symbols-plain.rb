# encoding: ASCII
# symbols-plain.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     27-Aug-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.34

class Deplate::Symbols::Plain < Deplate::Symbols
    self.myname = 'plain'

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
end

