# encoding: ASCII
# html-highstep.rb
# @Author:      Tom Link (micathom AT gmail com)
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     2007-01-06.
# @Last Change: 2009-11-09.
# @Revision:    0.34
#
# = Description
# Provide the macro ''step'' to mark text for stepwise highlighting.

class Deplate::Macro::HighStep < Deplate::Macro::FormattedText
    attr_reader :step_index
    register_as 'step'
    def setup(text)
        @step_index = @deplate.formatter.stepwise_next
        super
    end
    def process
        format_particle(:format_highstep, self, super)
    end
end

class Deplate::Formatter
    def format_highstep(invoker, txt=nil)
        format_emphasize(invoker, txt)
    end
end

class Deplate::Formatter::HTML
    def format_highstep(invoker, txt=nil)
        txt ||= invoker.elt || invoker.text
        idx = invoker.step_index
        beg = (@variables['stepwiseBegin'] || '0').to_i
        cls = (beg == 0 or idx > beg) ? 'steppreview' : 'stephighlight'
        args = {
            # 'style' => "visibility:#{vis};"
            'class' => cls,
            'id' => "HighStep#{idx}",
        }
        inline_tag(invoker, 'span', txt, args)
    end
end

