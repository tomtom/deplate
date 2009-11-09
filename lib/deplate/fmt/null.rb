# encoding: ASCII
# null.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     17-Mär-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.3750

require 'deplate/formatter'

class Deplate::Formatter::NULL < Deplate::Formatter
    self.myname = 'null'
    self.rx     = /null?/i
    
    def format_particle(agent, invoker, *args)
        ''
    end

    def format_element(agent, invoker, *args)
        ''
    end

    def output(invoker, *body)
    end
end


class Deplate::Core
    def body_write
    end
end

