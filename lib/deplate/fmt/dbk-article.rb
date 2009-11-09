# encoding: ASCII
# dbk-article.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     17-Mär-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.2064

require "deplate/docbook"

class Deplate::Formatter::DbkArticle < Deplate::Formatter::Docbook
    self.myname = 'dbk-article'
    self.rx     = /dbk|dbk-article|docbook/i
    self.related = ['dbk']
    
    def initialize(deplate, args)
        @headings = ['sect1', 'sect2', 'sect3', 'sect4', 'sect5', 'sect6']
        super
    end
    
    def setup
        @deplate.variables['dbkClass']   ||= 'article'
    end
    
    # Document skeleton
    def get_doc_open(args)
        o = []
        lang = @deplate.options.messages.prop('lang', self)
        if lang
            o << %{ lang="#{lang}"}
        end
        return '<article%s>' % o.join
    end

    def get_doc_close(args)
        return '</article>'
    end

    def get_doc_head_open(args)
        return '<articleinfo>'
    end

    def get_doc_head_close(args)
        return '</articleinfo>'
    end
end

