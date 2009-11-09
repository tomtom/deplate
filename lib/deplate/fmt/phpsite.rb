# encoding: ASCII
# phpsite.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     17-Mär-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.921

require 'deplate/fmt/htmlsite'
require 'deplate/mod/php-extra'

# A variant of the htmlsite-formatter that is suited for php output.

class Deplate::Formatter::PhpSite < Deplate::Formatter::HTML_Site
    self.myname  = 'phpsite'
    self.related = ['php']
    self.rx      = /php[0-9]?/i
    self.suffix  = '.php'
end

