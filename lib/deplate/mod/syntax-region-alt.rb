# encoding: ASCII
# syntax-alt-region.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     27-Aug-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.22
# 
# Description:
# This module provides an alternative syntax for regions, like:
#
# ==== Region
# content
# ====
# 

class Deplate::Element::RegionSyntaxAlt < Deplate::Element::Region
    register_element
    set_rx(/^(\s*)(={4,})\s*([A-Z][A-Za-z]*)(.*)$/)

    def get_endrx
        /^#{get_indent}#{Regexp.escape(@match[2])}(\s+.*)?$/
    end

    def get_name
        @match[3]
    end

    def get_args
        @match[4]
    end

    def get_indent
        @match[1]
    end
end

