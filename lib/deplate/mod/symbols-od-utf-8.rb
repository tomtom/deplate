# encoding: ASCII
# symbols-od-utf-8.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     27-Aug-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.47

require 'deplate/mod/symbols-utf-8'

class Deplate::Symbols::Utf8_Od < Deplate::Symbols::Utf8
    self.myname = 'od-utf-8'

    def nonbreakingspace(invoker)
        %{<text:s/>}
    end
end

