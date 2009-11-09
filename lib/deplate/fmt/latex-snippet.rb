# encoding: ASCII
# latex-snippet.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     11-Aug-2005.
# @Last Change: 2009-11-09.
# @Revision:    0.17

require 'deplate/fmt/latex.rb'
require 'deplate/formatter-snippet.rb'

class Deplate::Formatter::LaTeX_Snippet < Deplate::Formatter::LaTeX
    self.myname = "latex-snippet"
    self.rx     = /(la)?tex(-snippet)?/i

    include Deplate::Snippet

    def format_paragraph(invoker)
        invoker.elt
    end
end

