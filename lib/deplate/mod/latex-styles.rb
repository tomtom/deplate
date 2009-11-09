# encoding: ASCII
# latex-emph-table-head.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     26-Nov-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.366
# 
# Description:
# 
# Usage:
# 
# TODO:
# 
# CHANGES:
# 


# The dummy base style
class Deplate::Formatter::LaTeX::Styles
    def initialize(deplate)
        @deplate   = deplate
        @formatter = deplate.formatter
    end
    
    def format_table(rv, invoker, *args)
        rv
    end

    def table_args(rv, invoker)
        rv
    end

    def table_bottom(rv, invoker, *args)
        rv
    end

    def table_caption(rv, invoker, *args)
        rv
    end

    def table_caption_text(rv, invoker, *args)
        rv
    end
    
    def table_cell(rv, invoker, *args)
        rv
    end

    def table_cols(rv, invoker, *args)
        rv
    end

    def table_begin_head(rv, invoker, rown)
        rv
    end
    
    def table_end_head(rv, invoker, rown)
        rv
    end
    
    def table_begin_body(rv, invoker, rown)
        rv
    end
    
    def table_end_body(rv, invoker, rown)
        rv
    end
    
    def table_begin_foot(rv, invoker, rown)
        rv
    end
    
    def table_end_foot(rv, invoker, rown)
        rv
    end

    def table_head_row(rv, invoker, *args)
        rv
    end

    def table_horizontal_ruler(rv, invoker, *args)
        rv
    end

    def table_horizontal_ruler_from_to(rv, invoker, *args)
        rv
    end

    def table_longtable_bottom(rv, invoker, *args)
        rv
    end

    def table_longtable_top(rv, invoker, *args)
        rv
    end

    def table_normal_row(rv, invoker, *args)
        rv
    end

    def table_head_row(rv, invoker, *args)
        rv
    end

    def table_foot_row(rv, invoker, *args)
        rv
    end

    def table_high_row(rv, invoker, *args)
        rv
    end

    def table_table_bottom(rv, invoker, *args)
        rv
    end

    def table_table_top(rv, invoker, *args)
        rv
    end

    def table_tabular_top(rv, invoker)
        rv
    end

    def table_tabular_bottom(rv, invoker)
        rv
    end

    def table_top(rv, invoker, *args)
        rv
    end
    
    def tabular_col_widths(rv, invoker, args)
        rv
    end
    
    def tabular_col_justifications(rv, invoker, args)
        rv
    end
    
    def tabular_vertical_rulers(rv, invoker, args)
        rv
    end

    def table_indented_row(rv, invoker, row, indent, t)
        rv
    end
    
    protected
    def with_agent(agent, *args)
        @formatter.send(agent, *args)
    end

    def horizontal_ruler(invoker, rv, args={})
        m = /^\s+/.match(rv)
        indent = m ? m[0] : ""
        indent + with_agent(:table_horizontal_ruler_from_to, invoker, args)
    end
    
    def first_row?(invoker, rowidx)
        rowidx == 0
    end
    
    def last_row?(invoker, rowidx)
        invoker.elt.size - 1 == rowidx
    end

    def cell_in_first_row?(invoker, cell)
        cell.y == 1
    end
    
    def cell_in_last_row?(invoker, cell)
        cell.from_bottom - cell.span_y == 0
    end
    
    def cell_in_first_column?(invoker, cell)
        cell.x == 1
    end
    
    def cell_in_last_column?(invoker, cell)
        cell.from_right - cell.span_x == 0
    end
end


# Smaller font sizes
# class Deplate::Formatter::LaTeX::Styles::TableSmall < Deplate::Formatter::LaTeX::Styles
#     def table_cell(rv, invoker, *args)
#         %{\\small{#{rv}}}
#     end
# end
# class Deplate::Formatter::LaTeX::Styles::TableFootnotesize < Deplate::Formatter::LaTeX::Styles
#     def table_cell(rv, invoker, *args)
#         %{\\footnotesize{#{rv}}}
#     end
# end
# class Deplate::Formatter::LaTeX::Styles::TableScriptsize < Deplate::Formatter::LaTeX::Styles
#     def table_cell(rv, invoker, *args)
#         %{\\scriptsize{#{rv}}}
#     end
# end
class Deplate::Formatter::LaTeX::Styles::TableSmall < Deplate::Formatter::LaTeX::Styles
    def table_tabular_top(rv, invoker)
        "\\small{}\n#{rv}"
    end
    def table_tabular_bottom(rv, invoker)
        "#{rv}\n\\normalsize{}"
    end
    def table_caption_text(rv, invoker, *args)
        "\\normalsize{#{rv}}"
    end
end
class Deplate::Formatter::LaTeX::Styles::TableFootnotesize < Deplate::Formatter::LaTeX::Styles
    def table_tabular_top(rv, invoker)
        "\\footnotesize{}\n#{rv}"
    end
    def table_tabular_bottom(rv, invoker)
        "#{rv}\n\\normalsize{}"
    end
    def table_caption_text(rv, invoker, *args)
        "\\normalsize{#{rv}}"
    end
end
class Deplate::Formatter::LaTeX::Styles::TableScriptsize < Deplate::Formatter::LaTeX::Styles
    def table_tabular_top(rv, invoker)
        "\\scriptsize{}\n#{rv}"
    end
    def table_tabular_bottom(rv, invoker)
        "#{rv}\n\\normalsize{}"
    end
    def table_caption_text(rv, invoker, *args)
        "\\normalsize{#{rv}}"
    end
end


# Denser tables
class Deplate::Formatter::LaTeX::Styles::TableDense08 < Deplate::Formatter::LaTeX::Styles
    @@dense08baselinestretch = false
    def initialize(deplate)
        super
        # unless @@dense08baselinestretch
        #     @formatter.output_at(:pre, :body_beg, "\\newcommand{\\origBaseLineStretch}{}")
        #     @@dense08baselinestretch = true
        # end
    end
    def table_top(rv, invoker, capAbove, rown)
        "\\renewcommand{\\arraystretch}{0.8}\n\\setlength{\\tabcolsep}{0.8\\tabcolsep}\n#{rv}"
    end
    def table_bottom(rv, invoker, capAbove, rown)
        "#{rv}\\setlength{\\tabcolsep}{1.25\\tabcolsep}\n\\renewcommand{\\arraystretch}{1.0}\n"
    end
end


# Displays tables as a box
class Deplate::Formatter::LaTeX::Styles::TableLandscape < Deplate::Formatter::LaTeX::Styles
    def initialize(deplate)
        super
        @formatter.add_package("lscape")
    end
    def table_top(rv, invoker, capAbove, rown)
        "\\begin{landscape}\n#{rv}"
    end
    def table_bottom(rv, invoker, capAbove, rown)
        "#{rv}\\end{landscape}\n"
    end
end


# Displays tables as a grid
class Deplate::Formatter::LaTeX::Styles::TableGrid < Deplate::Formatter::LaTeX::Styles
    def table_bottom(rv, invoker, *args)
        [horizontal_ruler(invoker, rv, :bottom => true), rv].join("\n")
    end

    def table_top(rv, invoker, *args)
        [rv, horizontal_ruler(invoker, rv, :top => true)].join("\n")
    end

    def table_indented_row(rv, invoker, row, indent, t)
        if row.from_bottom == 0
            rv
        else
            [rv, horizontal_ruler(invoker, rv)].join("\n")
        end
    end
    
    def tabular_vertical_rulers(rv, invoker, *args)
        [1] * (@formatter.table_row_size(invoker.elt) + 1)
    end
end


# Displays tables as found in scientific textbooks
# <+TBD+> We should also use booktabs.sty here
class Deplate::Formatter::LaTeX::Styles::TableFormal < Deplate::Formatter::LaTeX::Styles
    def table_args(rv, *args)
        rv + %{ rules="groups"}
    end
    
    def table_bottom(rv, invoker, *args)
        [horizontal_ruler(invoker, rv, :bottom => true), rv].compact.join("\n")
    end

    def table_top(rv, invoker, *args)
        [rv, horizontal_ruler(invoker, rv, :top => true)].compact.join("\n")
    end
    
    def table_end_head(rv, invoker, *args)
        [rv, horizontal_ruler(invoker, rv)].compact.join("\n")
    end
    
    def table_begin_foot(rv, invoker, *args)
        [horizontal_ruler(invoker, rv), rv].compact.join("\n")
    end
end

# List
class Deplate::Formatter::LaTeX::Styles::TableList < Deplate::Formatter::LaTeX::Styles
    def table_bottom(rv, invoker, *args)
        [horizontal_ruler(invoker, rv, :bottom => true), rv].compact.join("\n")
    end

    def table_top(rv, invoker, *args)
        [rv, horizontal_ruler(invoker, rv, :top => true)].compact.join("\n")
    end
    
    def table_indented_row(rv, invoker, row, indent, t)
        if row.from_bottom == 0
            rv
        else
            [rv, horizontal_ruler(invoker, rv)].join("\n")
        end
    end
end

# Displays tables as a box
class Deplate::Formatter::LaTeX::Styles::TableBox < Deplate::Formatter::LaTeX::Styles::TableFormal
    def tabular_vertical_rulers(rv, invoker, *args)
        rv[0] = 1
        rv[@formatter.table_row_size(invoker.elt)] = 1
        prototype = invoker.elt[0]
        prototype.cols.each_with_index do |c, i|
            if c.high
                rv[i + 1] = rv[i] = 1
            end
        end
        rv
    end
end


# Try some coloring
class Deplate::Formatter::LaTeX::Styles::TableOverlay < Deplate::Formatter::LaTeX::Styles::TableBox
    def initialize(deplate)
        super
        options = []
        options << "pdftex" if deplate.options.pdftex
        @formatter.add_package("colortbl", *options)
    end

    def table_head_row(rv, invoker, row, nth)
        rv[0] = styled_head_row_color(rv[0])
        rv
    end

    def table_foot_row(rv, invoker, row, nth)
        rv[0] = styled_foot_row_color(rv[0])
        rv
    end

    def table_cell(rv, invoker, cell, row)
        if cell.high and !row.head and !row.foot
            styled_high_cell_color(rv)
        else
            rv
        end
    end

    def styled_head_row_color(rv)
        %{\\rowcolor[gray]{.8}#{rv}}
    end

    def styled_foot_row_color(rv)
        %{\\rowcolor[gray]{.9}#{rv}}
    end

    def styled_high_cell_color(rv)
        %{\\cellcolor[gray]{.9}#{rv}}
    end
end



class Deplate::Formatter::LaTeX
    @style_classes = {
        "grid"         => Deplate::Formatter::LaTeX::Styles::TableGrid,
        "formal"       => Deplate::Formatter::LaTeX::Styles::TableFormal,
        "box"          => Deplate::Formatter::LaTeX::Styles::TableBox,
        "overlay"      => Deplate::Formatter::LaTeX::Styles::TableOverlay,
        "list"         => Deplate::Formatter::LaTeX::Styles::TableList,
        "small"        => Deplate::Formatter::LaTeX::Styles::TableSmall,
        "footnotesize" => Deplate::Formatter::LaTeX::Styles::TableFootnotesize,
        "scriptsize"   => Deplate::Formatter::LaTeX::Styles::TableScriptsize,
        "dense08"      => Deplate::Formatter::LaTeX::Styles::TableDense08,
        "landscape"    => Deplate::Formatter::LaTeX::Styles::TableLandscape,
    }

    class << self
        attr_accessor :style_classes
    end
    
    def formatter_initialize_latex_styles
        @style_engines = {
            :default => Deplate::Formatter::LaTeX::Styles.new(@deplate),
        }
        @format_advice_backlist += [:format_table]

        table_agents = [
            :format_table, :table_args, 
            :table_bottom, :table_caption, :table_caption_text, :table_cell, :table_cols, 
            :table_begin_head, :table_end_head, :table_head_row, 
            :table_begin_foot, :table_end_foot, :table_foot_row, 
            :table_begin_body, :table_end_body, :table_high_row, :table_normal_row,
            :table_horizontal_ruler, :table_horizontal_ruler_from_to,
            :table_longtable_top, :table_longtable_bottom, 
            :table_table_bottom, :table_table_top, :table_top,
            :table_tabular_top, :table_tabular_bottom,
            :tabular_col_widths, :tabular_col_justifications, :tabular_vertical_rulers,
            :table_indented_row,
        ]
        for agent in table_agents
            advice = Proc.new do |agent, rv, invoker, *args|
                styles = []
                stylex_arg = invoker.args["stylex"]
                if stylex_arg
                    styles += Deplate::Core.split_list(stylex_arg, ',', ';')
                else
                    style_arg = invoker.args["style"]
                    styles += Deplate::Core.split_list(style_arg, ',', ';') if style_arg
                    style_var = @deplate.variables["tableStyle"]
                    styles += Deplate::Core.split_list(style_var, ',', ';') if style_var
                end
                styles.compact!
                style_arg = invoker.args["style"]
                for style in styles
                    styler = @style_engines[style] || setup_styler(style)
                    if styler
                        style_arg.delete(style) if style_arg
                        rv = styler.send(agent, rv, invoker, *args)
                    end
                end
                rv
            end
            def_advice("latex-styles", agent, :wrap => advice)
        end
    end

    def setup_styler(style)
        # <+TBD+> load module or style definition on-demand
        c = self.class.style_classes[style]
        if c
            @style_engines[style] = styler = c.new(@deplate)
            return styler
        else
            log(["Unknown style", style], :error)
            @style_engines[:default]
        end
    end

end

