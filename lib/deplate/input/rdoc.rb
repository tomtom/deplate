# encoding: ASCII
# rdoc.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     10-Mär-2005.
# @Last Change: 2009-11-09.
# @Revision:    0.301
#
# = Description
# Based upon Programming Ruby 2, 190ff
# = TODO
# The :main: and :callseq: directives are not implemented yet.

require 'deplate/wiki-markup'

# Deplate: rdoc input
class Deplate::Input::Rdoc < Deplate::Input
    self.myname = 'rdoc'

    def initialize(deplate, args)
        args[:elements] = [
            Deplate::Input::Rdoc::Directive,
            Deplate::Input::Wiki::HeadingPrefixEqual,
            Deplate::Input::Wiki::OrderedNotIndented,
            Deplate::Input::Wiki::OrderedSharpNotIndented,
            Deplate::Input::Wiki::ItemizeNotIndented,
            Deplate::Input::Rdoc::Description4,
            Deplate::Input::Rdoc::Description3,
            Deplate::Input::Rdoc::Description2,
            Deplate::Input::Rdoc::Description1,
            Deplate::Input::Wiki::Break3Hyphens,
            # Deplate::Input::Rdoc::NoProcess,
            Deplate::Element::Whitespace,
        ]
        args[:particles] = [
            # Deplate::Particle::Escaped,
            Deplate::Input::Rdoc::LabelledLink2,
            Deplate::Input::Rdoc::LabelledLink,
            Deplate::Input::Wiki::ImgUrl,
            Deplate::Input::Rdoc::Link,
            Deplate::HyperLink::Url,
            Deplate::Input::Wiki::ItalicWordSingleUnderscore,
            Deplate::Input::Wiki::BoldWordSingleAsterisk,
            Deplate::Input::Wiki::TypewriterWordSinglePlus,
            Deplate::Input::Rdoc::Italic2,
            Deplate::Input::Rdoc::Italic3,
            Deplate::Input::Rdoc::Bold2,
            Deplate::Input::Rdoc::Typewriter2,
        ]
        args[:particles_ext] = []
        args[:commands] = {
            'include'   => Deplate::Input::Rdoc::Include,
            'title'     => Deplate::Input::Rdoc::Title,
            'maketitle' => Deplate::Command::MAKETITLE,
            'author'    => Deplate::Command::AUTHOR,
        }
        args[:regions] = {}
        args[:macros] = {}
        args[:onthefly_particles] = false
        args[:paragraph_class]    = Deplate::Input::Rdoc::ParagraphOrVerbatim
        args[:comment_class]      = Deplate::Input::Rdoc::NoProcess
        args[:command_class]      = Deplate::Input::Rdoc::Directive
        super
    end
end

class Deplate::Input::Rdoc::ParagraphOrVerbatim < Deplate::Input::Wiki::ParagraphIndentedVerbatim
    set_rx Deplate::Input::Wiki::ParagraphIndentedVerbatim.rx
    def setup
        super
        @args['wrap'] ||= @deplate.variables['verbatimMargin'] || '72'
    end

    def to_be_continued?(line, klass, match)
      if klass == Deplate::Element::Whitespace
        return line.size > 0
      else
        super
      end
    end
end

class Deplate::Input::Rdoc::Italic2 < Deplate::Particle::Emphasize
    set_rx(/^<em>(.+?)<\/em>/)
end

class Deplate::Input::Rdoc::Italic3 < Deplate::Particle::Emphasize
    set_rx(/^<i>(.+?)<\/i>/)
end

class Deplate::Input::Rdoc::Bold2 < Deplate::Particle::Emphasize
    set_rx(/^<b>(.+?)<\/b>/)
    def setup
        @args['style'] = 'bold'
        update_styles
        super
    end
end

class Deplate::Input::Rdoc::Typewriter2 < Deplate::Particle::Code
    set_rx(/^<tt>(.+?)<\/tt>/)
end

class Deplate::Input::Rdoc::Link < Deplate::HyperLink::Extended
    set_rx(/^link:([^+*&<>,.\t :!?#]+(\.\w+)?)(#([^+*?&<>\\\/,.:!?]+?))?/)
    
    def get_destination
        @match[1]
    end

    def get_interwiki
        nil
    end

    def get_anchor
        @match[4]
    end

    def get_name
        nil
    end

    def get_modifier
        nil
    end
end

class Deplate::Input::Rdoc::LabelledLink < Deplate::HyperLink::Extended
    set_rx(/^(\S+)\[((file|https?|mailto|ftps?|www):.*?)(#(.+))?\]/)
    
    def get_destination
        @match[2]
    end

    def get_interwiki
        nil
    end

    def get_anchor
        @match[5]
    end

    def get_name
        @match[1]
    end

    def get_modifier
        nil
    end
end

class Deplate::Input::Rdoc::LabelledLink2 < Deplate::HyperLink::Extended
    set_rx(/^\{(.+?)\}\[((file|https?|mailto|ftps?|www):.*?)(#(.+))?\]/)
    
    def get_destination
        @match[2]
    end

    def get_interwiki
        nil
    end

    def get_anchor
        @match[5]
    end

    def get_name
        @match[1]
    end

    def get_modifier
        nil
    end
end

class Deplate::Input::Wiki::OrderedSharpNotIndented < Deplate::List::Ordered
    include Deplate::Input::Wiki::ListExtra
    set_rx(/^(()(#)[ \t]+)(.+)$/)
end

class Deplate::Input::Rdoc::Description1 < Deplate::Input::Wiki::AbstractDescription
    # set_rx(/^(()(\S.*?)\b::[ \t]+)(.*)$/)
    set_rx(/^(()(\S.*?)::)(([ \t]+)(.*))?$/)
    def_get :text, 6

    def to_be_continued?(line, klass, match)
      unless @accum.empty?
        return false
      end
      case klass
      when Deplate::Input::Rdoc::ParagraphOrVerbatim
        return line =~ /^\s+/
      else
        super
      end
    end
end

class Deplate::Input::Rdoc::Description2 < Deplate::Input::Wiki::AbstractDescription
    set_rx(/^(()\+(.*?)\+::[ \t]+)(.*)$/)
end

class Deplate::Input::Rdoc::Description3 < Deplate::Input::Wiki::AbstractDescription
    set_rx(/^(()\[(.+?)\][ \t]+)(.*)$/)
end

class Deplate::Input::Rdoc::Description4 < Deplate::Input::Wiki::AbstractDescription
    set_rx(/^(()\[\+(.+?)\+\][ \t]+)(.*)$/)
end

class Deplate::Input::Rdoc::NoProcess < Deplate::Element
    set_rx(/^(\s*)#--/)
   
    def setup
        @endRx = /^(\s*)#\+\+/
    end

    def finish
    end
end

class Deplate::Input::Rdoc::Directive < Deplate::Element::Command
    set_rx(/^\s*:(call-seq|include|title|main|stopdoc|startdoc|enddoc|maketitle|author):\s*(.*?)\s*$/)
    @enddoc = false
   
    class << self
        def is_volatile?(match, input)
            case match[1]
            when "title"
                true
            else
                false
            end
        end
        
        def accumulate(src, array, deplate, text, match)
            cmd = match[1]
            Deplate::Core.log(["New element", cmd, text], :debug)
            begin
                args = {}
                text = match[2]
                case cmd
                when "stopdoc"
                    deplate.switches << true
                when "startdoc"
                    unless @enddoc
                        deplate.switches.pop until deplate.switches.empty?
                    end
                when "enddoc"
                    deplate.switches << true
                    @enddoc = true
                else
                    if !deplate.switches.last
                        cc = deplate.input.commands[cmd]
                        if cc
                            cc.do_accumulate(src, array, deplate, text, match, args, cmd)
                        else
                            Deplate::Core.log(["Unknown or unhandled directive", cmd, match[0]], :error, src)
                        end
                    end
                end
            rescue Deplate::DontFormatException
                Deplate::Core.log(["Dropping", match[0]], nil, src)
            end
        end
    end
end

class Deplate::Input::Rdoc::Include < Deplate::Command
    def self.accumulate(src, array, deplate, text, match, args, cmd)
        Deplate::Core.log("%s: %s" % [cmd, text], :debug)
        if File.exists?(text)
            deplate.include_file(array, text)
        else
            Deplate::Core.log(["File not found", text], :error, src)
        end
    end
end

class Deplate::Input::Rdoc::Title < Deplate::Command
    def self.accumulate(*args)
         Deplate::Command::TITLE.accumulate(*args)
         Deplate::Command::MAKETITLE.accumulate(*args)
    end
end

# <+TBD+>
# :call-seq:
#   lines. . .
# :main: name

class Deplate::Core
    def input_initialize_rdoc
        unless @variables['inputFormat']
            @options.input_class = Deplate::Input::Rdoc
            @variables['inputFormat'] = Deplate::Input::Rdoc.myname
        end
    end
end

