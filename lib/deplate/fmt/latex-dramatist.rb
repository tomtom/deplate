# encoding: ASCII
# latex-dramatist.rb
# @Last Change: 2009-11-09.
# Author::      Tom Link (micathom AT gmail com)
# License::     GPL (see http://www.gnu.org/licenses/gpl.txt)
# Created::     2007-08-09.
#
# = Description
# = Usage
# = TODO
# = CHANGES

require 'deplate/fmt/latex.rb'

class Deplate::Formatter::LaTeX_Dramatist < Deplate::Formatter::LaTeX
    self.myname = 'latex-dramatist'
    self.rx     = /(la)?tex(-dramatist)?/i
    self.related = ['latex']

    self.latexDocClass  = 'book'
    # self.latexVariables = ['11pt', 'a4paper']


    def formatter_initialize_dramatist
        @ignored_styles << /^play/
    end

    def prepare_headings
        @headings  = ['Scene']
        @headings0 = ['scene']
    end

    def prepare_dramatist
        add_package('dramatist')
        # output_at(:pre, :body_beg, %{\\pagestyle{myheadings}})
    end

    # +++
    def format_heading(invoker, level=nil, elt=nil, args=nil)
        # elt ||= invoker.elt
        # if elt.empty?
            args  ||= invoker.args
            level ||= invoker.level
            hd     = @headings0[level - 1]
            mod    = heading_mod(args)
            cap    = heading_caption(invoker)
            labels = invoker && format_label(invoker, :string)
            join_blocks(["\n\\#{hd}#{mod}#{cap}{}", labels])
        # else
        #     super
        # end
    end
   

    # Open stage directions.
    # \StageDir{...}
    def format_paragraph(invoker)
        if invoker.args['plain']
            super
        else
            join_blocks([wrap_text("\\StageDir{%s}" % invoker.elt), ""])
        end
    end


    def format_CAST(invoker)
        return '\\DramPer{}'
    end


    def format_ACT(invoker)
        elt = invoker.elt
        if elt.empty?
            return '\\act{}'
        else
            return '\\Act{%s}' % elt
        end
    end

    # * Unordered -> stage directions or cast group
    # * Descriptions -> dialog or cast
    #
    # Cast list:
    # \Character[NAME]{Name}{name}
    # \begin{CharacterGroup}{NAME}
    # \GCharacter[NAME]{Name}{name}
    # ...
    # \end{CharacterGroup}
    # \DramPer
    #
    # Dialog:
    # \namespeaks \direct{...} ...
    def format_list_item(invoker, type, level, item, args={})
        indent = format_indent(level, true)
        ctag   = list_wide? ? '' : :empty
        explv  = list_item_explicit_value(item)
        if explv
            explv = %{[#{explv}]}
        end
        case type
        when 'Itemize'
            if is_cast?(invoker)
                return wrap_text("#{indent}\\begin{CharacterGroup}{#{item.body}}", :indent => "  "), "#{indent}\\end{CharacterGroup}"
            else
                return wrap_text("#{indent}\\StageDir{#{item.body}}", :indent => "  "), ctag
            end
        when 'Description'
            if is_cast?(invoker)
                full_name    = [item.item.upcase, item.body].compact.join(', ')
                display_name = item.item
                tex_name     = speaker(item.item)
                if level > 1
                    char = '%s\\GCharacter{%s}{%s}{%s}'
                    full_name << ','
                else
                    char = '%s\\Character[%s]{%s}{%s}'
                    full_name << '.'
                end
                return wrap_text(char % [indent, full_name, display_name, tex_name], :indent => "  "), ctag
            else
                speaker = item.item.sub(/^(\S+)/) {|t| speaker($1) + 'speaks'}
                return wrap_text("#{indent}\\#{speaker} #{item.body}", :indent => "  "), ctag
            end
        else
            super
        end
    end


    def is_cast?(invoker)
        return invoker.args['cast'] || invoker.tagged_as?('cast')
    end

    
    def speaker(name)
        name.downcase
    end


    def format_list_env(invoker, type, level, what, subtype=nil)
        indent = format_indent(level)
        if is_cast?(invoker)
            return ''
        else
            case what
            when :open
                w    = "begin"
                if list_wide?
                    pre  = "\n#{indent}"
                    post = "\n"
                else
                    pre  = indent
                    post = ""
                end
            when :close
                w    = "end"
                pre  = indent
                post = ""
            end
            if level == 0 and type == 'Description' and !invoker.args['plain']
                "#{pre}\\#{w}{drama}#{post}"
            else
                ''
            end
        end
    end


    # Stage direction
    # \direct{...}
    def format_direct(invoker, text=nil)
        "\\direct{%s}" % (text || invoker.elt || invoker.text)
    end

end

