# encoding: ASCII
# dbk-article.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     17-Mär-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.2060

require "deplate/docbook"
require "deplate/fmt/dbk-article"

class Deplate::Formatter::DbkArticle412 < Deplate::Formatter::DbkArticle
    self.myname = "dbk-article-4.1.2"
    self.rx     = /dbk|dbk-article|docbook/i
    self.related = ['dbk']

    def setup
        @deplate.variables['dbkClass']   ||= 'article'
        @deplate.variables['dbkVersion'] ||= '4.1.2'
    end
end

