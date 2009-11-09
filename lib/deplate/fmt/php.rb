# encoding: ASCII
# php.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     17-Mär-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.917

require 'deplate/fmt/html'
require 'deplate/mod/php-extra'

# A variant of the html-formatter that is suited for php output.

class Deplate::Formatter::Php < Deplate::Formatter::HTML
    self.myname = 'php'
    self.rx     = /php[0-9]?/i
    self.suffix = '.php'
end

