# encoding: ASCII
#!/usr/bin/env ruby
# deplate-string.rb
# @Author:      Tom Link (micathom AT gmail com)
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     31-Dez-2005.
# @Last Change: 2009-11-09.
# @Revision:    0.43

require 'deplate/converter'

class DeplateString < String
    @deplate_options = Deplate::Core.deplate_options
    @deplate_options.included = true

    class << self
        attr_reader :deplate_options
    end

    attr_reader :deplate_options
    attr_reader :deplate_variables
    attr_reader :deplate_converter

    def initialize(*args)
        @deplate_options = self.class.deplate_options.dup
        super
    end
    
    def with_deplate_options(&block)
        block.call(@deplate_options)
    end
    
    def deplate(fmt)
        @deplate_converter = Deplate::Converter.new(fmt,
                                     :options => @deplate_options)
        rv = @deplate_converter.convert_string(self)
        @deplate_variables = @deplate_converter.deplate.variables
        rv
    end
    
    def to_html
        deplate('html')
    end

    def to_xhtml
        deplate('xhtml10t')
    end

    def to_latex
        deplate('latex')
    end

    def to_tex
        deplate('latex')
    end

    def to_text
        deplate('plain')
    end

    def to_dbk
        deplate('dbk-article')
    end
end


if __FILE__ == $0
    puts DeplateString.new('bar __foo__ bar').to_html
    puts DeplateString.new('bar __foo__ bar').to_xhtml
    puts DeplateString.new('bar __foo__ bar').to_tex
    puts DeplateString.new('bar __foo__ bar').to_text
    puts DeplateString.new('bar __foo__ bar').to_dbk

    t = <<EOF
* Introduction

''deplate'' is a tool for converting wiki-like markup to latex, html, or 
"html-slides".
EOF

    puts DeplateString.new(t).to_html
end

