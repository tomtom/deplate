# encoding: ASCII
# latex-verbatim-small.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     20-Nov-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.30
# 
# Description:
# 
# Usage:
# 
# TODO:
# 
# CHANGES:
# 

class Deplate::Formatter::LaTeX
    def formatter_initialize_latex_verbatim_small
        def_advice("latex-verbatim-small", :format_verbatim,
                  :wrap => Proc.new do |agent, rv, *rest|
                    join_blocks(["{\\" + (@variables["verbSize"] || "footnotesize{}"),
                                rv, 
                                "}"])
                  end 
                 )
    end
end

