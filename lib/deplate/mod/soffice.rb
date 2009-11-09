# encoding: ASCII
# mod-soffice.rb - Some OpenOffice specific modifications to the html output
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     27-Jun-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.13
# 
# Description:
# Some OpenOffice specific modifications to the html output
# 
# TODO:
# ToC, LoT, LoF, Index, Bib, citations, references, labels etc.
# 
# CHANGES:
# 

class Deplate::Formatter::HTML
    def format_pagenumber(invoker)
        "<SDFIELD TYPE=PAGE SUBTYPE=RANDOM FORMAT=PAGE></SDFIELD>"
    end
end

