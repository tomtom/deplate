# encoding: ASCII
# @Last Change: 2009-11-09.
# Author::      Tom Link (micathom AT gmail com)
# License::     GPL (see http://www.gnu.org/licenses/gpl.txt)
# Created::     2008-04-13.


require 'math_ml/string'


class Deplate::Formatter::HTML
    alias :inlatex_re_mathml :inlatex
    def inlatex(invoker)
        case invoker
        when Deplate::Macro::Math
        else
            inlatex_re_mathml(invoker)
        end
    end

    alias :format_math_re_mathml :format_math
    def format_math(invoker)
        case @deplate.formatter.class.myname
        when 'xhtml11m'
        else
            invoker.log(['Inadequate formatter', @deplate.formatter.class.myname], :error)
        end
        block, formula = bare_latex_formula(invoker.text)
        if formula
            begin
                mathml = formula.to_mathml(block)
                return mathml.to_s
            rescue Exception => e
                invoker.log(['Error in module', 'mathml', e], :error)
            end
        else
            invoker.log(['Internal error', invoker.text], :error)
        end
    end
end

