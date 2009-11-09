# encoding: ASCII
# formatter-snippet.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     11-Aug-2005.
# @Last Change: 2009-11-09.
# @Revision:    0.6

module Deplate::Snippet
    def formatter_initialize_snippet
        unless @deplate.options.included
            log(['Not run in included mode'], :error)
            log(['Set included mode'], :error)
            @deplate.options.included = true
        end
    end
end
