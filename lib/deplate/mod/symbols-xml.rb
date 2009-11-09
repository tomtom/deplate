# encoding: ISO-8859-1
# symbols-sgml.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     27-Aug-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.33

require "deplate/mod/symbols-utf-8"

class Deplate::Symbols::XML < Deplate::Symbols::Utf8
    self.myname = :xml
    
    def symbol_quote(invoker)
        "&quot;"
    end

    def symbol_gt(invoker)
        "&gt;"
    end

    def symbol_lt(invoker)
        "&lt;"
    end

    def symbol_amp(invoker)
        "&amp;"
    end
end

