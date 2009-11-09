# encoding: ASCII
# wiki-markup.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     10-Mär-2005.
# @Last Change: 2009-11-09.
# @Revision:    0.287
#
# = Description
# Various elements for defining input filters
# = Usage
# = TODO
# = CHANGES

require "deplate/abstract-class"

module Deplate::Input::Wiki; end

# Textstyles
# Italic
class Deplate::Input::Wiki::ItalicWordSingleUnderscore < Deplate::Particle::Emphasize
    set_rx(/^\b_(\S+?)_\b/)
end

class Deplate::Input::Wiki::ItalicDoubleSlash < Deplate::Particle::Emphasize
    set_rx(/^\b\/\/(\S+?)\/\/\b/)
end


# Bold 
class Deplate::Input::Wiki::Bold < Deplate::Particle::Emphasize
    def setup
        @args['style'] = 'bold'
        update_styles
        super
    end
end

class Deplate::Input::Wiki::BoldWordSingleAsterisk < Deplate::Input::Wiki::Bold
    set_rx(/^\B\*(\S+?)\*\B/)
end

class Deplate::Input::Wiki::BoldDoubleAsterisk < Deplate::Input::Wiki::Bold
    set_rx(/^\*\*(\S+?)\*\*/)
end


# Superscript
class Deplate::Input::Wiki::Superscript < Deplate::SimpleParticle
    set_formatter :format_superscript
end

class Deplate::Input::Wiki::SuperscriptTagSup < Deplate::Input::Wiki::Superscript
    set_rx(/^<sup>(.*?)<\/sup>/)
end


# Subscript
class Deplate::Input::Wiki::Subscript < Deplate::SimpleParticle
    set_formatter :format_subscript
end

class Deplate::Input::Wiki::SubscriptTagSub < Deplate::Input::Wiki::Subscript
    set_rx(/^<sub>(.*?)<\/sub>/)
end


# Strikethrough
class Deplate::Input::Wiki::StrikeThrough < Deplate::Particle::Emphasize
    def setup
        @args['style'] = 'strikethrough'
        update_styles
        super
    end
end

class Deplate::Input::Wiki::StrikethroughTagDeleted < Deplate::Input::Wiki::StrikeThrough
    set_rx(/^<deleted>(.*?)<\/deleted>/)
end


# Typewriter
class Deplate::Input::Wiki::TypewriterWordSinglePlus < Deplate::Particle::Code
    set_rx(/^\B\+(\S+?)\+\B/)
end

module Deplate::Input::Wiki::AbstractImg
    def image_args
        {}
    end
    
    def image_process
        args = @args.dup
        args.update(image_args)
        @elt = @deplate.formatter.include_image(self, @dest, args, true)
    end
end

# Treat a reference to an image as included images. Requires subclassing and a 
# definition of @rx.
class Deplate::Input::Wiki::ImgUrl < Deplate::HyperLink::Url
    set_rx(/^((file|https?|mailto|ftps?|www):(\S+?)\.(png|jpg|jpeg|gif|bmp))\b/)
    include Deplate::Input::Wiki::AbstractImg
    alias :process :image_process
end

# Treat non-indented text as paragraph, indented as verbatim.
class Deplate::Input::Wiki::ParagraphIndentedVerbatim < Deplate::Element::Paragraph
    set_rx(/^([ \t]*)(.+)[ \t]*$/)
    set_formatter nil
    attr_reader :regNote

    def get_text
        @leading_whitespace = @match[1]
        @keep_whitespace    = !@leading_whitespace.empty?
        @match[2]
    end
    
    def to_be_continued?(line, klass, match)
        if super
            indent = get_indent(line).size
            return @level > 0 || indent == 0
        else
            return false
        end
    end
    
    def format_special
        if @level == 0
            format_as_paragraph
        else
            @elt = @leading_whitespace + @accum.join("\n")
            # p "DBG format_special", @deplate.input.class, @deplate.input.elements, @elt
            format_as_verbatim
        end
    end

    def format_as_paragraph
        format_element(:format_paragraph, self)
    end

    def format_as_verbatim
      # <+TBD+> Register a code region in rdoc
      # if @deplate.variables['codeSyntax']
      #   r = Deplate::Element::Region.new(@deplate, @source, @accum, @match, 'Code', @args)
      #   r = r.finish
      #   r = r.process
      #   r = r.format_compound
      #   r
      # else
        margin = @args["wrap"]
        if margin
            @elt = @deplate.formatter.wrap_text(@elt, :margin => margin.to_i)
        end
        format_element(:format_verbatim, self)
      # end
    end
end

module Deplate::Input::Wiki::ListExtra
    def continuation_level_ok?(otherLevel, thisLevel, thisMaxLevel)
        return (otherLevel > 0 and otherLevel >= thisLevel and otherLevel <= thisMaxLevel)
    end
end

class Deplate::Input::Wiki::OrderedNotIndented < Deplate::List::Ordered
    include Deplate::Input::Wiki::ListExtra
    set_rx(/^(()([0-9]+\.|[a-zA-Z]\.)[ \t]+)(.+)$/)
end

class Deplate::Input::Wiki::ItemizeNotIndented < Deplate::List::Itemize
    include Deplate::Input::Wiki::ListExtra
    set_rx(/^(()([-*])[ \t]+)(.+)$/)
end

# Requires subclassing & definition of @rx.
class Deplate::Input::Wiki::AbstractDescription < Deplate::List::Description
    include Deplate::Input::Wiki::ListExtra
end

# Heading
class Deplate::Input::Wiki::HeadingPrefixEqual < Deplate::Element::Heading
    set_rx(/^(=+)[ \t]+(.*?)$/)
end

class Deplate::Input::Wiki::HeadingEqual < Deplate::Element::Heading
    set_rx(/^(=+)[[:blank:]]*(.*?)[[:blank:]]*\1$/)
end

# Page Break
class Deplate::Input::Wiki::Break3Hyphens < Deplate::Element::Break
    set_rx(/^\s*-{3,}\s*$/)
end

