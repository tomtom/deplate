# encoding: ASCII
# html-snippet.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     11-Aug-2005.
# @Last Change: 2009-11-09.
# @Revision:    0.15

require 'deplate/fmt/html.rb'
require 'deplate/formatter-snippet.rb'

class Deplate::Formatter::HTML_Snippet < Deplate::Formatter::HTML
    self.myname = "html-snippet"

    include Deplate::Snippet

    def format_paragraph(invoker)
        invoker.elt
    end
end

