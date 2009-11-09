# encoding: ASCII
# code-highlight.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     27-Feb-2005.
# @Last Change: 2009-11-09.
# @Revision:    0.69
#
# = Description
# Highlight code regions using André Simon's 
# highlight[http://www.andre-simon.de/]. Adds 
# Deplate::Regions::Code#highlight.
# 
# = Usage
# = TODO
# = CHANGES


class Deplate::Formatter::LaTeX
    def hook_code_process_highlight(style)
        unless @deplate.options.did_highlight_init
            style_ext = Deplate::Regions::Code::get_style_ext(style)
            add_package(%{color})
            add_package(%{alltt})
            add_package(%{highlight#{style_ext}})
            @deplate.options.did_highlight_init = true
        end
    end
end

class Deplate::Regions::Code
    add_highlighter(nil, 'html',          :highlight)
    add_highlighter(nil, 'htmlslides',    :highlight)
    add_highlighter(nil, 'htmlsite',      :highlight)
    add_highlighter(nil, 'html-snippet',  :highlight)
    add_highlighter(nil, 'php',           :highlight)
    add_highlighter(nil, 'phpsite',       :highlight)
    add_highlighter(nil, 'xhtml10t',      :highlight)
    add_highlighter(nil, 'xhtml11m',      :highlight)
    add_highlighter(nil, 'latex',         :highlight)
    add_highlighter(nil, 'latex-snippet', :highlight)

    class << self
        def get_style_ext(style)
            style_ext = style ? "-#{style}" : nil
        end
    end
    
    def highlight(syntax, style, text)
        unless @deplate.allow_external
            return
        end
        formatter = @deplate.formatter
        style_ext = Deplate::Regions::Code::get_style_ext(style)
        args      = []
        # if defined?(Deplate::Formatter::XHTML10transitional) and formatter.kind_of?(Deplate::Formatter::XHTML10transitional)
        if formatter.formatter_related?('xhtml')
            mode      = :xhtml
            args      << "--xhtml"
            style_out = "highlight#{style_ext}.css"
        # elsif defined?(Deplate::Formatter::HTML) and formatter.kind_of?(Deplate::Formatter::HTML)
        elsif formatter.formatter_related?('html')
            mode      = :html
            # args      << "--css-outfile=highlight#{style_ext}.css"
            # args      << "--style-outfile=highlight#{style_ext}.css"
            style_out = "highlight#{style_ext}.css"
            css       = formatter.head_link_tag(%{rel="stylesheet" type="text/css" href="#{style_out}"})
            log(["Code: You need to copy highlight's style definition", "highlight#{style_ext}.css"], :anyway)
            @postponed_format << Proc.new do |container|
                container.deplate.formatter.union_at(:pre, :css, css)
            end
        # elsif defined?(Deplate::Formatter::LaTeX) and formatter.kind_of?(Deplate::Formatter::LaTeX)
        elsif formatter.formatter_related?('latex')
            mode      = :latex
            args      << "--latex"
            if @deplate.options.messages.prop('lang', formatter) == 'german'
                args << '-r'
            end
            style_out = "highlight#{style_ext}.sty"
            log(["Code: You need to copy highlight's style definition", "highlight#{style_ext}.sty"], :anyway)
        # elsif defined?(Deplate::Formatter::Docbook) and formatter.kind_of?(Deplate::Formatter::Docbook)
        elsif formatter.formatter_related?('dbk')
            log("Code: 'highlight' doesn't support docbook!", :error)
            return nil
        else
            log("Code: 'highlight' cannot create output for this formatter!", :error)
            return nil
        end
        if style
            style = %{--style=#{style}}
        end
        tw  = @deplate.variables["tabwidth"] || 4
        cmd = "#{Deplate::External.get_app('highlight')} --fragment --wrap --replace-tabs=#{tw} --syntax #{syntax} --style-outfile=#{style_out} #{style} #{args.join(' ')}"
        Deplate::External.log_popen(self, cmd) do |io|
            io.puts(text)
            io.close_write
            # text = io.read
            text = io.readlines.collect {|l| l.chomp}
        end
        case mode
        when :html, :xhtml
            # text = [%{<div class="code">}, "<pre>", text, "</pre>", %{</div>}].join
            text = [%{<div class="code">}, "<pre>", text, "</pre>", %{</div>}]
        end
        return text
    end
end

