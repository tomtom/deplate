# encoding: ASCII
# ru_koi8-r.rb -- Standard messages
# @Authors:     Maxim Komar (komar from ukr.net), Tom Link (micathom AT gmail com)
# @Website:     http://komar.org.ua
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     01-Sep-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.64

require 'deplate/messages'

class Deplate::Messages::RuKoi8r < Deplate::Messages
    setup 'ru'
    def_prop 'lang', 'ru'
    def_prop 'latex_lang', 'russian'
    def_prop 'latex_lang_cmd', %{\\usepackage[russian]{babel}}
    def_prop 'encoding', 'koi8-r'
    load_catalog 'ru.koi8-r'
end

