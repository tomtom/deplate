# encoding: ASCII
# html-deplate-button.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     05-Sep-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.26

class Deplate::Formatter::HTML
    def prepare_html_deplate_button
        buttons = %{<a href="http://deplate.sourceforge.net"><img src="http://deplate.sourceforge.net/deplate-mini.png" border="0" alt="deplate Logo" /></a>}
        output_at(:post, :html_pageicons, buttons) unless buttons.empty?
    end
end

