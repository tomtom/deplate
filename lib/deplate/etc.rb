# encoding: ASCII
# etc.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     16-Okt-2005.
# @Last Change: 2009-11-09.
# @Revision:    0.328

require 'deplate/common'


module Deplate::Rx
    # This function builds recursive regular expressions that are used 
    # for parsing macros and skeletons. The optional argument defines 
    # the depth of nested macros for which the regular expression is 
    # being built. The default is 5 which should be sufficient due to 
    # the primitivity of the macro language. The string "{#}" is 
    # replaced with the regexp itself.
    def builder(rx_source, rx_opts=nil, depth=5, sol=true)
        rxr = rx_source.gsub('\\', '\\\\\\\\')
        for i in 1..depth
            rx_source.gsub!(/\{#\}/, rxr)
        end
        rx_source.gsub!(/\{#\}/, '[^{}]+?')
        rx_source = '^' + rx_source if sol
        return Regexp.new(rx_source, rx_opts)
    end
    module_function :builder
end

class Deplate::PseudoContainer < Deplate::BaseElement
    attr_accessor :registered_metadata
    attr_reader   :destination
    
    def initialize(deplate, args)
        super(deplate, args)
        self.level_as_string = args[:level_as_string]
        @top_heading         = args[:top] || deplate.get_current_top
        @registered_metadata = args[:metadata] || []
        @accum               = args[:accum] || []
        @destination         = ''
    end
    
    def log(text, condition=nil)
        Deplate::Core.log(text, condition, @source)
    end

    def output_file_name(args={})
        basename = args[:basename]
        rv = @top_heading ? @top_heading.output_file_name : @destination
        if basename
            return File.basename(rv)
        else
            return rv
        end
    end
end


class Deplate::NullTop < Deplate::PseudoContainer
    attr_reader   :args, :caption, :level_heading
    attr_accessor :first_top, :last_top, :description

    def initialize(deplate, args)
        super
        @level_heading = [0]
        @destination = args[:destination]
        @args        = {:id => 'deplateNullTop'}
        @caption     = Deplate::CaptionDef.new(deplate.msg('[Start]'), {}, nil)
        @description = nil
        @first_top   = false
        @last_top    = false
    end
    
    alias :output_location :output_file_name
end


module Deplate::Footnote
    attr_reader :fnId
    # Quack like Deplate::Region
    attr_reader :accum, :regNote, :label, :level, :caption, :captionOptions

    def footnote_setup(text)
        if text
            @fnId = @args['id']
            if @fnId and text and !text.empty?
                # @regNote = @fnId
                @accum   = text
                # @level   = @container.level
                fn = Deplate::Regions::Footnote.new(@deplate, @source, @fnId, {}, self)
                fn.finish
                fn.elt.each {|e| e.args[:minor] = true}
            else
                @fnId ||= text
            end
            if @container.kind_of?(Deplate::Element::Table)
                @container.contains_footnotes = true
            end
        else
            log('No footnote ID', :error)
        end
    end

    def footnote_process
        fn = @deplate.footnotes[@fnId]
        if fn
            # fn.elt.consumed = true
            fn.fn_consumed = true
            @elt = fn
        else
            log(['Unknown footnote', @fnId, @deplate.footnotes.keys.inspect], :error)
            @elt = nil
        end
        return format_particle(:format_footnote, self)
    end
end


class Deplate::IndexEntry
    attr_accessor :container, :name, :synonymes, :label
    attr_writer :file, :level_as_string
    
    def initialize(container)
        @container = container
        # p "DBG IndexEntry: container = nil" unless container
        if block_given?
            yield(self)
        end
    end

    def file(invoker=nil)
        # @file || (@container && @container.output_file_name(:relative => invoker))
        @file
    end

    def level_as_string
        # @level_as_string || (@container && @container.level_as_string)
        @level_as_string
    end
end


class Deplate::Source
    attr_accessor :file, :begin, :end, :level_as_string, :stats
    
    def initialize(*args)
        @file, @stats, @begin, @end, @level_as_string = args
    end

    def log(text, mode)
        Deplate::Core.log(text, mode, self)
    end
end


# module Deplate::Symbols
# end


module Deplate::Void
    module_function
end

# Based on code by:
# From: Florian Gross, flgr AT ccan.de
# Newsgroups: comp.lang.ruby
# Subject: Re: safe eval?
# Date: Mon, 10 May 2004 19:52:27 +0200
# Message-ID: <2g9tqcFbpc6U1@uni-berlin.de>
module Deplate::Safe; end
class << Deplate::Safe
    def safe(level, code, sandbox=nil)
        error = nil

        begin
            thread = Thread.new do
                $-w = nil
                sandbox ||= Object.new.taint
                yield(sandbox) if block_given?
                $SAFE = level
                eval(code, sandbox.send(:binding))
            end
            value = thread.value
            result = Marshal.load(Marshal.dump(thread.value))
        rescue Exception => error
            error = Marshal.load(Marshal.dump(error))
        end

        return result, error
    end
end


class Deplate::Symbols < Deplate::CommonObject
    class_attribute :myname

    class << self
        def hook_post_myname=(name)
            klass = self
            Deplate::Core.declare_symbols(name, klass)
        end

        def register_as(*names)
            for n in names
                hook_post_myname=(n)
            end
        end
    end

    def initialize(deplate)
        @deplate   = deplate
        @formatter = @deplate.formatter
    end
    
    def symbol_quote(invoker)
        '"'
    end

    def symbol_gt(invoker)
        ">"
    end

    def symbol_lt(invoker)
        "<"
    end

    def symbol_amp(invoker)
        "&"
    end

    def doublequote_open(invoker)
        %{"}
    end

    def doublequote_close(invoker)
        %{"}
    end

    def singlequote_open(invoker)
        %{'}
    end

    def singlequote_close(invoker)
        %{'}
    end

    def nonbreakingspace(invoker)
        %{ }
    end

    # def symbol_paragraph(invoker)
    #     # %{ยง}
    #     %{ง}
    # end

    def format_symbol(invoker, sym)
        return @formatter.plain_text(sym)
    end
end

