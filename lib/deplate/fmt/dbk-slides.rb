# encoding: ASCII
# dbk-slides.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     29-Apr-2005.
# @Last Change: 2009-11-09.
# @Revision:    0.17

require 'deplate/docbook'

# <+TBD+>Untested
class Deplate::Formatter::DbkSlides < Deplate::Formatter::Docbook
    self.myname = 'dbk-slides'
    self.rx     = /dbk|dbk-slides|docbook/i
    self.related = ['dbk']
    
    def initialize(deplate, args)
        @headings = ['foilgroup', 'foil']
        super
    end
    
    def setup
        @deplate.variables['dbkClass'] ||= 'slides'
    end
    
    # Document skeleton
    def get_doc_open(args)
        o = []
        lang = @deplate.options.messages.prop('lang', self)
        if lang
            o << %{ lang="#{lang}"}
        end
        return "<slides#{o.join}>"
    end

    def get_doc_close(args)
        return '</slides>'
    end

    def get_doc_head_open(args)
        return '<slidesinfo>'
    end

    def get_doc_head_close(args)
        return '</slidesinfo>'
    end
end

