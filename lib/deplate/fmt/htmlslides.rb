# encoding: ASCII
# fmt-html.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     17-Mär-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.812

require "deplate/fmt/htmlsite"

# This is html-site with the paragraph swallowing.
class Deplate::Formatter::HTML_Slides < Deplate::Formatter::HTML_Site
    self.myname = "htmlslides"
    self.rx     = /html?|htmlslides/i

    alias :format_paragraph_html :format_paragraph
    def format_paragraph(invoker)
        super if invoker.args["noSwallow"] or @deplate.variables["noSwallow"]
    end
end

