# encoding: ASCII
# output.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     04-Dez-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.268

require 'forwardable'
require 'deplate/metadata'

# Description:
# 
# Usage:
# 
# TODO:
# 
# CHANGES:
# 

class Deplate::Output
    extend Forwardable

    attr_accessor :pre_matter, :body, :post_matter
    attr_accessor :top_heading, :index
    attr_accessor :destination
    attr_reader :attributes
    # , :metadata
    
    def_delegator(:@deplate, :slot_by_name)
    def_delegator(:@deplate, :log)
    def_delegator(:@deplate, :call_methods_matching)
 
    def_delegator(:@meta, :merge_metadata)
    def_delegator(:@meta, :push_metadata)
    def_delegator(:@meta, :metadata_available?)
    def_delegator(:@meta, :metadata_destination)
    def_delegator(:@meta, :format_metadata)
    def_delegator(:@meta, :metadata)
    def_delegator(:@meta, :metadata=)

    class << self
        def reset
            @@pre_matter_template  = Array.new
            @@body_template        = Array.new
            @@post_matter_template = Array.new
            @@idx = 0
        end
    end
   
    def initialize(deplate, inherited_output=nil)
        @@idx += 1
        @deplate     = deplate
        @formatter   = deplate.formatter
        @options     = deplate.options
        @variables   = deplate.variables
        @templates   = deplate.templates
        @meta        = Deplate::Metadata.new(deplate, self)
        @attributes  = {}
        # @metadata    = {}
        @destination = nil
        @index       = nil
        @output      = nil
        if inherited_output
            @pre_matter  = inherited_output.pre_matter.dup
            @body        = @@body_template.dup
            @post_matter = inherited_output.post_matter.dup
        else
            @pre_matter  = @@pre_matter_template.dup
            @body        = @@body_template.dup
            @post_matter = @@post_matter_template.dup
        end
        @top_heading     = nil
        @body_empty_done = false
        reset
    end

    def reset
        @attributes[:stepwiseIdx] = 0
        @attributes[:consumed_labels] = []
        @attributes[:consumed_ids] = []
    end
    alias :simulate_reset :reset

    def body_flush
        call_methods_matching(@formatter, /^hook_pre_body_flush_/)
        save!
        log(['Flushing formatted elements', @destination], :debug)
        process
        call_methods_matching(@formatter, /^hook_post_body_flush_/)
    end
    
    def save!
        unless do_i_feel_empty?
            call_methods_matching(@formatter, /^hook_pre_output_save_/)
            @index       ||= @top_heading.top_index
            @destination ||= @top_heading.destination
            @pre_matter    = @pre_matter.dup
            @body          = @body.dup
            @post_matter   = @post_matter.dup
            call_methods_matching(@formatter, /^hook_post_output_save_/)
        end
        log(['Save output', destination], :debug)
    end

    def process
        if @options.included
            peel!
        else
            tmpl = @options.template || @variables['template']
            if tmpl
                if File.exist?(tmpl)
                    fill_in_template(tmpl)
                else
                    template_file = @templates[tmpl]
                    if template_file
                        log(['Using template', template_file], :debug)
                        fill_in_template(template_file)
                    else
                        log(['Unknown template', tmpl], :error)
                        flatten!
                    end
                end
            else
                flatten!
            end
        end
    end

    def body_empty?
        @body_empty = @body.compact.flatten.empty?
        log(["Body is empty", caller[0..5]], :debug) if @body_empty
        @body_empty
    end

    def do_i_feel_empty?
        if @body_empty_done
            @body_empty
        else
            @body_empty_done = true
            body_empty?
        end
    end
    # private :do_i_feel_empty?
  
    def peel!
        unless do_i_feel_empty?
            @output = @body.flatten.compact
        end
    end
    
    def flatten!
        unless do_i_feel_empty?
            @output = [@pre_matter, @body, @post_matter].flatten.compact
        end
    end

    def fill_in_template(template_file)
        unless do_i_feel_empty?
            t = Deplate::Template.new(:file => template_file, :master => @deplate)
            @output = t.fill_in(@deplate, 
                                :pre  => @pre_matter,
                                :body => @body,
                                :post => @post_matter)
        end
    end

    def join(sep)
        @output.join(sep) if @output
    end

    def pos_and_array(type, pos)
        if type == :array
            arr = [pos]
            pos = 0
        else
            pos = slot_by_name(pos)
            unless pos or pos == 0
                log(["Undefined slot", pos, type], :error) if pos.nil?
                return
            end
            case type
            when :body, "body"
                arr = @body
            when :pre, "preMatter", "pre"
                arr = @pre_matter
            when :post, "postMatter", "post"
                arr = @post_matter
            when :array
            else
                raise "Unknown type: #{type}"
            end
        end
        return pos, arr
    end

    def empty_at?(type, pos)
        pos, arr = pos_and_array(type, pos)
        slot = arr[pos]
        return slot.nil? || slot.empty?
    end
    
    def add_at(type, pos, *text)
        text = text.compact
        unless text.empty?
            negative = false
            pos, arr = pos_and_array(type, pos)
            if pos
                negative = pos ? pos < 0 : false
                if text.first == :prepend
                    negative = true
                    text.shift
                end
                pos = pos.abs
                if arr[pos].nil?
                    arr[pos] = text
                else
                    for t in text
                        if block_given?
                            arr[pos] = yield(arr[pos], t)
                        elsif negative
                            arr[pos].unshift(t)
                        else
                            arr[pos] << t
                        end
                    end
                end
                @formatter.join_blocks(text)
            else
                log(["No slot", text], :error)
            end
        end
    end

    def union_at(type, pos, *text)
        add_at(type, pos, *text) do |arr, t|
            if !arr.include?(t)
                arr << t
            else
                arr
            end
        end
    end
    
    def set_at(type, pos, *text)
        add_at(type, pos, *text) do |arr, t|
            t
        end
    end

end

Deplate::Output.reset


