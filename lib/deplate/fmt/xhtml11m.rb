# encoding: ASCII
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     2008-04-14.
# @Last Change: 2009-11-09.
# @Revision:    0.45

require "deplate/fmt/xhtml10t"

# An uninformed hack to enable mathml.
class Deplate::Formatter::XHTML11m < Deplate::Formatter::XHTML10transitional
    self.myname   = "xhtml11m"
    self.rx     = /x?html?/i
    self.suffix = ".xhtml"

    def head_doctype
        enc = canonic_encoding(nil, 'latin1' => 'ISO-8859-1')
        return <<HEADER
<?xml version="1.0" encoding="#{enc}"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1 plus MathML 2.0//EN" "http://www.w3.org/Math/DTD/mathml2/xhtml-math11-f.dtd">
HEADER
    end

end

