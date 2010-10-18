# encoding: ASCII
# play.rb
# @Author:      Tom Link (micathom AT gmail com)
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     2007-03-31.
# @Last Change: 2010-10-18.
# @Revision:    0.221

# require 'deplate/input/deplate.rb'

class Deplate::Input::Play < Deplate::Input
    self.myname = 'play'

    class << self
        def styled_text(style, text)
            "{text style=#{style}: #{Deplate::Core.escape_characters(text, :esc => '{}')}}"
        end
    end

    def initialize(deplate, args)
        # deplate.log('WARNING: The play class is in flux and will most likely change', :anyway)
        args_fill_with_default(args)
        args[:elements] = [
            Deplate::Element::Command,
            Deplate::Element::Region,
            Deplate::Input::Play::Heading,
            Deplate::Input::Play::Directive,
            Deplate::Input::Play::Dialog,
            Deplate::Element::Anchor,
            Deplate::Element::Table,
            Deplate::Element::Whitespace,
        ]
        args[:commands] = Deplate::Command.commands
        args[:commands]['ACT'] = Deplate::Input::Play::ACT
        args[:commands]['CAST'] = Deplate::Input::Play::CAST

        # args[:particles] = Deplate::Particle.particles + [
        #     Deplate::Input::Play::Direct,
        # ]
        args[:particles] = [
            Deplate::Input::Play::Direct,
        ] + Deplate::Particle.particles
        args[:paragraph_class] = Deplate::Input::Play::General
        super
    end
end


class Deplate::Input::Play::ACT < Deplate::Command
    register_as 'ACT'
    set_formatter :format_ACT
end


class Deplate::Input::Play::CAST < Deplate::Command
    register_as 'CAST'
    set_formatter :format_CAST
end


class Deplate::Input::Play::Direct < Deplate::SimpleParticle
    set_rx(/^\[([^\[].*?)\]/)
    # set_rx(/^\(\((.*?)\)\)/)
    def_get :text, 1
    set_formatter :format_direct
end

class Deplate::Input::Play::Heading < Deplate::Element::Heading
    def finish
        # m = /^((.*?)\s*::\s*)?(.*?)(\s*--\s*((I|E|X|INT.?|EXT.?|\<|\>)\/)?(.*?))\s*?$/.match(@accum.join)
        m = /^((.*?)\s*::\s*)?(.*?)(\s*--\s*((.*?)\/)?(.*?))?\s*?$/.match(@accum.join)
        # @args['plain'] = true
        @args['playScene']    = m[2]
        @args['playLocation'] = m[3]
        @args['playIntExt']   = m[6] || ''
        @args['playTime']     = m[7] || ''
        # style = @deplate.variables['playStyle'] || @deplate.variables['class'] || 'hollywood'
        style = @deplate.variables['playStyle'] || 'hollywood'
        meth  = "style_#{style}"
        if respond_to?(meth)
            @accum = send(meth)
        else
            log(['Unknown style', style], :error)
            @accum = []
        end
        update_styles(['play'])
        # self.html_args = [self.html_args, 'class="play"'].join(' ')
        # "{text style=play-intext: #{}" unless .empty?
        # "{text style=play-location: #{m[2].gsub(/[{}]/, '\\\\\\0')}}",
        # "{text style=play-time: #{m[3].gsub(/[{}]/, '\\\\\\0')}}",
        super
    end

    def style_hollywood
        intext = get_intext()
        accum = []
        accum << Deplate::Input::Play.styled_text('play-intext', intext) unless intext.empty?
        accum << Deplate::Input::Play.styled_text('play-location', @args['playLocation'])
        if (time = get_time)
            accum << Deplate::Input::Play.styled_text('play-flexsep', '--') << 
                Deplate::Input::Play.styled_text('play-right', time)
        end
        [accum.join(' ')]
    end

    def style_austria
        intext = get_intext('AUSSEN', 'INNEN')
        accum = []
        accum << Deplate::Input::Play.styled_text('play-location', @args['playLocation'])
        accum << Deplate::Input::Play.styled_text('play-flexsep', '--')
        accum << Deplate::Input::Play.styled_text('play-right', [intext, '/', get_time].join)
        [accum.join(' ')]
    end

    def get_intext(ext='EXT.', int='INT.')
        intext = @args['playIntExt']
        case intext.upcase
        when 'I', 'INT', 'INT.', '<'
            intext = @deplate.variables['int'] || int
        when 'X', 'E', 'EXT', 'EXT.', '>', 'A'
            intext = @deplate.variables['ext'] || ext
        # else
        #     intext = @deplate.variables['int'] || int
        end
        intext
    end

    def get_time
        ti = @args['playTime']
        case ti.upcase
        when 'D', 'T'
            @deplate.msg('Day')
        when 'N'
            @deplate.msg('Night')
        when 'M'
            @deplate.msg('Morning')
        when 'A', 'E'
            @deplate.msg('Evening')
        else
            ti
        end
    end
end

class Deplate::Input::Play::Directive < Deplate::List::Itemize
    # register_element
    set_rx(/^(([[:blank:]]+)([-+])[[:blank:]]+)(.+)$/)
    self.listtype = 'Itemize'

    def finish_elt
        # update_styles(['play-directive'])
        update_styles(['play'])
        super
    end
end

class Deplate::Input::Play::Dialog < Deplate::List::Description
    # register_element
    # set_rx(/^(([[:blank:]]+)(.+?)[[:blank:]]+::[[:blank:]])(.*)$/)
    self.listtype = 'Description'

    def finish_item
        # sp_alias = @deplate.variables['alias']
        # if sp_alias
        #     @item.sub!(/^[[:upper:]]+/) do |text|
        #         sp_alias[text] || text
        #     end
        # end
        # m = /^(.+?)\s+\[(.+?)\]$/.match(@item)
        # p = nil
        # if m
        #     p = m[1]
        #     acc = [Deplate::Input::Play.styled_text('play-character', m[1])]
        #     acc << '{nl}' << Deplate::Input::Play.styled_text('play-direct', m[2]) if m[2]
        #     @item = acc.join
        # else
        # p = @item.match(/^\S+/)[0]
        p = @item
        @item = Deplate::Input::Play.styled_text('play-character', @item)
        if @deplate.variables['castShortNames'] and @deplate.variables['castShortNames'].has_key?(p)
            p = @deplate.variables['castShortNames'][p]
        end
        @args['tag'] = [@args['tag'], "#{Deplate::Core.clean_name(p, :extra => ' ')}_speaks"].compact.join(',')
        # update_styles('play')
        super
    end

    def process
        if @args['cast'] or tagged_as?('cast')
            push_styles(['play-cast'])
        else
            push_styles(['play-dialog'])
        end
        super
    end
end

class Deplate::Input::Play::General < Deplate::Element::Paragraph
    def setup
        update_styles(['play-description'])
        super
    end
end

class Deplate::Core
    def input_initialize_play
        # unless @variables['inputFormat']
            @options.input_class = Deplate::Input::Play
        #     @variables['inputFormat'] = @options.input_class.myname
        # end
    end
end

