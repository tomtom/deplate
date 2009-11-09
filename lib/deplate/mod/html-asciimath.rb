# encoding: ASCII
# html-asciimath.rb -- Support for asciimath.js
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     30-Dez-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.46

class Deplate::Formatter::HTML
    def formatter_initialize_html_asciimath
        if @deplate.variables["bodyOptions"]
            @deplate.variables["bodyOptions"] += %{ onload="translate()"}
        else
            @deplate.variables["bodyOptions"] = %{onload="translate()"}
        end
        if @deplate.variables["htmlDefEtc"]
            @deplate.variables["htmlDefEtc"] += %{ xmlns:mml="http://www.w3.org/1998/Math/MathML"}
        else
            @deplate.variables["htmlDefEtc"] = %{xmlns:mml="http://www.w3.org/1998/Math/MathML"}
        end

        @special_symbols["$"] = Proc.new{|e| e == :pre ? "$" : "\\$"}
        @special_symbols["`"] = Proc.new{|e| e == :pre ? "`" : "\\`"}
        build_plain_text_rx
    end

    def prepare_html_asciimath
        output_at(:pre, :mod_head, <<END_OF_HTML
<object id="mathplayer" classid="clsid:32F66A20-7614-11D4-BD11-00104BD3F987">
</object><?import namespace="mml" implementation="#mathplayer"?>
<script type="text/javascript" src="ASCIIMathML.js"></script>
END_OF_HTML
                 )
    end

    def format_math(invoker)
        return invoker.text
    end
end

