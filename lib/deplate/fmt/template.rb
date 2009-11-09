# encoding: ASCII
# template.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     25-Mär-2005.
# @Last Change: 2009-11-09.
# @Revision:    0.24
#
# = Description
# The formatter for templates

# A pseudo-formatter used for templates.
class Deplate::Formatter::Template < Deplate::Formatter
    self.myname = "template"
    self.rx     = /template/i
    self.suffix = ".out"

    self.label_mode     = :delegate
    self.label_delegate = []
    self.label_once     = []

    def plain_text(text, escaped=false)
        return text
    end
    
    def format_unknown(invoker)
        invoker.elt
    end
    
    def format_paragraph(invoker)
        invoker.elt
    end
end

