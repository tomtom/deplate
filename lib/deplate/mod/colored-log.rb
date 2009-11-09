# encoding: ASCII
# colored-log.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     05-Mai-2005.
# @Last Change: 2009-11-09.
# @Revision:    0.5
#
# = Description
# Enable colored log output

class Deplate::Core
    def self.user_setup(options)
        enable_color(options)
    end
end

