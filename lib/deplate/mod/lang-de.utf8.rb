# encoding: ASCII
# mod-en.rb -- Standard messages
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     07-Mai-2004.
# @Last Change: 2010-09-19.
# @Revision:    0.86

require 'deplate/messages'

# German message catalog.
class Deplate::Messages::DeUTF8 < Deplate::Messages
    setup 'de.utf8'
    def_prop 'lang', 'de'
    def_prop 'latex_lang', 'german'
    def_prop 'latex_lang_cmd', %{\\usepackage{german}}
    load_catalog 'de.utf8'
end

