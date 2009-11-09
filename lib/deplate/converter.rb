# encoding: ASCII
#!/usr/bin/env ruby
# converter.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     14-Okt-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.148
# 
# = Description
# = Usage
#
#     require "deplate/converter"
#     t = <<EOF
#     * Introduction
# 
#     ''deplate'' is a tool for converting wiki-like markup to latex, html, or 
#     "html-slides".
#     EOF
#     to_html = Deplate::Converter.new
#     puts to_html.convert_string(t)
# 
# = TODO
# = CHANGES

require "deplate"

class Deplate::Converter
    attr_reader :options, :deplate

    @setup_done = false
    
    class << self
        attr_reader :setup_done
        
        def setup
            unless @setup_done
                Deplate::Core.collect_standard
                @setup_done = true
            end
        end
    end
    
    def initialize(formatter="html", args={})
        Deplate::Converter.setup
        @master            = args[:master]
        @options           = args[:options]
        @options         ||= @master.options.dup if @master
        @options         ||= Deplate::Core.deplate_options
        @options.fmt       = formatter
        @options.modules ||= args[:modules] || []
        Deplate::Core.require_standard(@options)
        if block_given?
            yield(self)
        end
        @deplate = Deplate::Core.new(formatter, :options => @options)
        vars   = args[:variables]
        vars ||= @master.variables.dup if @master
        @deplate.instance_eval {@variables = vars} if vars
        @formatter_method = "to_%s" % formatter.gsub(/[^[:alnum:]_]/, "_")
    end
    
    def convert_string(string)
        @deplate.send(@formatter_method, string)
    end

    def convert_file(filename)
        @deplate.send(@formatter_method, nil, filename)
    end
    
    def method_missing(method, *args, &block)
        if @deplate.respond_to?(method)
            @deplate.send(method, *args, &block)
        else
            super
        end
    end
end

# if __FILE__ == $0
#     t = <<EOF
# #DefCmd id=FOO <<
# FOO {arg: @body} FOO
# 
# * Introduction
# 
# ''deplate'' is a tool for converting wiki-like markup to latex, html, or 
# "html-slides".
# 
# #FOO: bla bla
# 
# EOF
#     to_html = Deplate::Converter.new
#     to_latex = Deplate::Converter.new("latex")
#     to_html_i = Deplate::Converter.new do |cvt|
#         cvt.options.included = true
#     end
#     # to_dbk = Deplate::Converter.new("dbk-article")
#    
#     puts "----------------------------------------------------------------"
#     puts to_html.convert_string(t)
#     puts "----------------------------------------------------------------"
#     puts to_html_i.convert_string(t)
#     puts "----------------------------------------------------------------"
#     puts to_latex.convert_string(t)
#     puts "----------------------------------------------------------------"
#     # puts to_dbk.convert_string(t)
#     puts "----------------------------------------------------------------"
#     
# end
#
