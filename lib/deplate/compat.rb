# compat.rb
# @Author:      Tom Link (micathom AT gmail com)
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     2009-01-22.
# @Last Change: 2009-11-09.
# @Revision:    0.0.4


module Deplate::Compat
    module_function

    def isRuby19
        return RUBY_VERSION !~ /^1\.[6-8]/
    end

end


# Local Variables:
# revisionRx: REVISION\s\+=\s\+\'
# End:
