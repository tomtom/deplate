# encoding: ASCII
# babelfish.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     05-Sep-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.25
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
    def prepare_babelfish
        if @deplate.formatter.matches?("html")
            babel = %{<script type="text/javascript" src="http://www.altavista.com/r?entr"></script>}
            # babel = %{<script type="text/javascript" src="http://www.altavista.com/r?inc_translate"></script>}
            output_at(:post, :pre_body_end, %{<div align="right" class="pageicons">%s</div>} % babel)
        end
    end
end

