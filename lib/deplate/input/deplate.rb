# encoding: ASCII
# deplate.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     10-Mär-2005.
# @Last Change: 2009-11-09.
# @Revision:    0.19
#
# = Description
# = Usage
# = TODO
# = CHANGES

# require ''

# Deplate: Standard input
class Deplate::Input::VikiDeplate < Deplate::Input
    self.myname = 'deplate'
end

class Deplate::Core
    def input_initialize_deplate
        @options.input_class = Deplate::Input
    end
end

