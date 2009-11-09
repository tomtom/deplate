# encoding: ASCII
# deplate-headings.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     10-Mär-2005.
# @Last Change: 2009-11-09.
# @Revision:    0.45

# require 'deplate/input/deplate.rb'

# Deplate: Headings only
class Deplate::Input::DeplateHeadings < Deplate::Input
    self.myname = 'deplate-headings'

    def initialize(deplate, args)
        args[:elements] ||= [
            Deplate::Element::Heading,
        ]
        args[:commands]  ||= []
        args[:regions]   ||= []
        args[:onthefly_particles] ||= false
        args[:paragraph_class]    ||= Deplate::Element::Swallowed
        args[:command_class]      ||= nil
        super
    end
end

class Deplate::Element::Swallowed < Deplate::Element::Paragraph
    set_formatter :format_paragraph
    set_rx(/^([ \t]*)(.*)[ \t]*$/)
    def finish
        nil
    end
end

class Deplate::Core
    def input_initialize_deplate
        unless @variables['inputFormat']
            @options.input_class = Deplate::Input::DeplateHeadings
            @variables['inputFormat'] = @options.input_class.myname
        end
    end
end

