# encoding: ASCII
# validate-html.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     05-Sep-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.24
# 
# Description:
# 
# Usage:
# 
# TODO:
# 
# CHANGES:
# 

class Deplate::Formatter::HTML
    def prepare_validate_html
        valid = []
        unless @deplate.variables["noHtmlValid"]
            valid << %{<a href="http://validator.w3.org/check?uri=referer"><img border="0"
                      src="http://www.w3.org/Icons/valid-html401"
                      alt="Valid HTML 4.01!" height="31" width="88"></a>}
        end
        unless @deplate.variables["noCssValid"]
            valid << %{<a href="http://jigsaw.w3.org/css-validator/">
                      <img style="border:0;width:88px;height:31px"
                       src="http://jigsaw.w3.org/css-validator/images/vcss" 
                       alt="Valid CSS!"></a>}
        end
        output_at(:post, :html_pageicons, valid) unless valid.empty?
    end
end

