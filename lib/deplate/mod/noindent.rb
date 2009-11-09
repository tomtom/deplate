# encoding: ASCII
# noindent.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     29-Aug-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.21
# 
# Description:
# Avoid inserting spaces and linebreaks

module Deplate::NoIndent
    def setup(context)
        class << context
            def join_blocks(blocks)
                blocks.join
            end
            
            def format_indent(level, shift=false)
                ""
            end
        end
    end
    module_function :setup
end

class Deplate::Core
    def module_initialize_noindent
        Deplate::NoIndent.setup(@formatter)
    end
end

