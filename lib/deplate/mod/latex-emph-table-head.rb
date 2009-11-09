# encoding: ASCII
# latex-emph-table-head.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     26-Nov-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.42
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
    def formatter_initialize_latex_emph_table_head
        def_advice("latex-emph-table-head", :table_end_head,
                  :wrap => Proc.new do |agent, rv, invoker, nth|
                    "#{rv}\n    #{table_horizontal_ruler_from_to(invoker)}"
                  end 
                 )
        def_advice("latex-emph-table-head", :table_cell,
                  :wrap => Proc.new do |agent, rv, invoker, cell, *args|
                    hirow = args[0]
                    hd = (hirow || cell.head || cell.foot || cell.high)
                    if hd
                        format_particle(:format_emphasize, invoker, rv)
                    else
                        rv
                    end
                  end 
                 )
    end
end

