# encoding: ASCII
# docbook-snippet.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     11-Aug-2005.
# @Last Change: 2009-11-09.
# @Revision:    0.21

require 'deplate/fmt/dbk-article.rb'
require 'deplate/formatter-snippet.rb'

class Deplate::Formatter::DbkSnippet < Deplate::Formatter::DbkArticle
    self.myname = "dbk-snippet"
    self.related = ['dbk']

    include Deplate::Snippet

    def format_paragraph(invoker)
        invoker.elt
    end
end

