# encoding: ISO-8859-1
#!/usr/bin/env ruby
# @Last Change: 2009-11-09.
# Author::      Tom Link (micathom AT gmail com)
# License::     GPL (see http://www.gnu.org/licenses/gpl.txt)
# Created::     2008-11-24.


require 'deplate/fmt/latex.rb'


class Deplate::Formatter::Sweave < Deplate::Formatter::LaTeX
    self.myname = 'sweave'
    self.rx     = /(la)?tex|sweave/i
    self.related = ['latex']
    self.suffix = ".Rnw"

    self.latexDocClass  = 'article'
    # self.latexVariables = ['11pt', 'a4paper']


    def prepare
        super
        sweave = @deplate.variables['sweaveOpts']
        if sweave
            output_at(:pre, :doc_def, "\\SweaveOpts{#{sweave}}")
        end
        sweavePath = @deplate.variables['sweavePath']
        if sweavePath
            # add_package('Sweave')
            add_package(sweavePath)
        end
    end


    def img_R(invoker, body)
        if invoker.args['noFloat']
            pre = post = nil
        else
            pre = with_agent(:figure_top, String, invoker)
            post = with_agent(:figure_bottom, String, invoker).strip
        end
        opts = sweave_options(invoker, 'fig=TRUE')
        return join_blocks([pre, "<<#{opts}>>=", body, '@', post].compact)
    end


    def region_R(invoker, body)
        opts = sweave_options(invoker)
        return join_blocks(["<<#{opts}>>=", body, '@'])
    end


    private

    def sweave_options(invoker, rest=nil)
        opts = [invoker.args['sweave'], rest]
        if (id = invoker.args[:id])
            opts << "label=#{id}"
        end
        if invoker.args[:hide]
            opts << 'results=hide'
        end
        ['print', 'echo', 'results', 'height', 'width', 'engine'].each do |arg|
            if invoker.args.has_key?(arg)
                opts << "#{arg}=#{sweave_value(invoker.args[arg])}"
            end
        end
        if invoker.args['swallow'] or invoker.args['drop']
            opts << 'echo=FALSE,print=FALSE,results=hide'
        end
        return opts.compact.join(',')
    end


    def sweave_value(value)
        case value
        when TrueClass
            return 'TRUE'
        when FalseClass
            return 'FALSE'
        else
            return value
        end
    end

end


class Deplate::Macro::Sweave < Deplate::Macro::Insert
    register_as 'sweave'
    register_as 'r'

    def setup(text)
        super
        @text = "\\Sexpr{#{@text}}"
    end
end



# Local Variables:
# revisionRx: REVISION\s\+=\s\+\'
# End:
