# encoding: ASCII
# html-jsmath.rb -- Support for jsmath.js
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     30-Dez-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.62

class Deplate::Formatter::HTML
    def prepare_html_jsmath
        output_at(:pre, :body_pre, <<END_OF_HTML
<script type="text/javascript" src="jsMath/jsMath.js"></script>
<noscript>
<div style="color:#CC0000; text-align:center">
  <b>Warning: <a href="http://www.math.union.edu/locate/jsMath">jsMath</a>
  requires JavaScript to process the mathematics on this page.<br/>
  If your browser supports JavaScript, be sure it is enabled.</b>
</div>
<hr/>
</noscript>
END_OF_HTML
                 )
        output_at(:post, :body_post, <<END_OF_HTML
<script> jsMath.Process() </script>
END_OF_HTML
                 )
    end

    alias :format_math_re_jsmath :format_math
    def format_math(invoker)
        block, formula = bare_latex_formula(invoker.text)
        if formula
            %{<span class="math">#{formula}</span>}
        else
            invoker.log(['Internal error', invoker.text], :error)
        end
    end
end

