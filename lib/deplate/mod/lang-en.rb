# encoding: ASCII
# mod-en.rb -- Standard messages
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     07-Mai-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.47

require 'deplate/messages'

# Proxy class for english messages
class Deplate::Messages::En < Deplate::Messages
    setup 'en'
    def_prop 'lang', 'en'
    def_prop 'latex_lang', 'english'
end

