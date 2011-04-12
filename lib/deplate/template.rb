# encoding: ASCII
# template.rb -- simple templates for deplate
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     10-Aug-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.564
# 
# Description:
# 
# Usage:
# 
# TODO:
# 
# CHANGES:
# 

require 'ostruct'
require 'deplate/formatter'
require 'deplate/fmt/template'


class Deplate::TemplateError < Exception
end


class Deplate::Command::Matter < Deplate::Command
    set_formatter :fill_in_template
    def process
        id = @args["id"] || @accum[0]
        @elt = template_get_content(id)
        if @elt
            return self
        else
            log(["PREMATTER: No content found", id], :error)
            return nil
        end
    end
end

class Deplate::Command::PREMATTER < Deplate::Command::Matter
    def template_get_content(arg)
        @deplate.options.template_manager.template_get_content(:pre, arg)
    end
end

class Deplate::Command::POSTMATTER < Deplate::Command::Matter
    def template_get_content(arg)
        @deplate.options.template_manager.template_get_content(:post, arg)
    end
end

class Deplate::Command::BODY < Deplate::Command::Matter
    def template_get_content(arg)
        @deplate.options.template_manager.template_get_content(:body, arg)
    end
end

class Deplate::Regions::Mingle < Deplate::Region
    set_line_cont false

    def finish
        finish_accum
        @doc_slot = nil
        @doc_type = nil
        slot = doc_slot
        type = doc_type
        case type
        when "pre", :pre
            array = @deplate.options.content_pre_matter
        when "body", :body
            array = @deplate.options.content_body
        when "post", :post
            array = @deplate.options.content_post_matter
        else
            log("Shouldn't be here", :error)
        end
        if array
            mingle_at(array, @deplate.slot_by_name(slot), @deplate.formatter.join_blocks(@accum))
        end
        return nil
    end

    def mingle_at(array, slot, text)
        if array[slot]
            array[slot] << text unless array[slot].include?(text)
        else
            array[slot] = [text]
        end
    end
end

class Deplate::DeplateForTemplates < Deplate::Core
    @log_treshhold = 4
    @log_events    = []
    @respect_line_cont = false
end

class Deplate::Template
    attr_reader :mingled

    @@templateKeys         = ['pre', 'body', 'post', 'doc', 'ARG', 'arg', 'clip']
    @@deplate_for_template = nil
    @@deplate_options = {
        :formatter          => Deplate::Formatter::Template,
        :onthefly_particles => false,
        :vanilla            => true,
        :inherit_options    => true,
        :paragraph_class    => Deplate::Element::Paragraph,

        :elements  => [
            Deplate::Element::Region,
            Deplate::Element::Command, 
            Deplate::Element::Whitespace,
        ],

        :commands  => {
            'INC'        => Deplate::Command::INC,
            'INCLUDE'    => Deplate::Command::INC,
            'GET'        => Deplate::Command::GET,
            'ARG'        => Deplate::Command::ARG,
            'XARG'       => Deplate::Command::XARG,
            'VAL'        => Deplate::Command::ARG,
            'XVAL'       => Deplate::Command::XARG,
            'DOC'        => Deplate::Command::VAR,
            'VAR'        => Deplate::Command::VAR,
            'OPT'        => Deplate::Command::OPT,
            'PROP'       => Deplate::Command::OPT,
            'PP'         => Deplate::Command::OPT,
            'PREMATTER'  => Deplate::Command::PREMATTER,
            'POSTMATTER' => Deplate::Command::POSTMATTER,
            'BODY'       => Deplate::Command::BODY,
            'WITH'       => Deplate::Command::WITH,
        },

        :regions   => {
            'Foreach' => Deplate::Regions::Foreach,
            'For'     => Deplate::Regions::Foreach,
            'Mingle'  => Deplate::Regions::Mingle,
            'Native'  => Deplate::Regions::Native,
            'Ruby'    => Deplate::Regions::Ruby,
            'Doc'     => Deplate::Regions::Var,
            'Var'     => Deplate::Regions::Var,
        },
        
        :particles => [
            Deplate::Particle::Escaped,
            Deplate::Particle::Macro,
            Deplate::Particle::Whitespace,
        ],

        :macros    => {
            'get'  => Deplate::Macro::Clip,
            'clip' => Deplate::Macro::Clip,
            'opt'  => Deplate::Macro::Opt,
            'arg'  => Deplate::Macro::Arg,
            'xarg' => Deplate::Macro::XArg,
            'val'  => Deplate::Macro::Arg,
            'xval' => Deplate::Macro::XArg,
            'var'  => Deplate::Macro::Var,
            'doc'  => Deplate::Macro::Var,
            'ruby' => Deplate::Macro::Ruby,
            'msg'  => Deplate::Macro::Msg,
            'date' => Deplate::Macro::Date,
        },
    }
   
    class << self
        def deplate_options
            @@deplate_options
        end

        def copy(deplate, src, dest, invoker=nil)
            tpl = File.open(src) {|io| io.read}
            src = invoker ? invoker.source : nil
            tpl = Deplate::Template.new(:template  => tpl,
                                        :source => src,
                                        :container => self)
            args = {}
            if block_given?
                yield(args)
            end
            Deplate::Define.let_variables(deplate, args) do
                tpl = tpl.fill_in(deplate, :source => src)
            end
            tpl = tpl.join("\n")
            File.open(dest, 'w') {|io| io.puts(tpl)}
        end
    end
    
    attr_reader :template, :pre, :body, :post
    
    def initialize(args)
        @source    = args[:source]
        @template  = args[:template]
        @container = args[:container]
        @master    = args[:master]
        # @deplate_options = @@deplate_options.dup
        @deplate_options = @@deplate_options
        if @master
            @deplate_options[:options] = @master.options.dup
            @deplate_options[:options].input_def = nil
            @deplate_options[:options].input_class = nil
        else
            @deplate_options[:options] = OpenStruct.new
        end
                        
        if @template
            return
        end
        file = args[:file]
        if file
            if File.exists?(file)
                begin
                    File.open(file) do |io|
                        @template = io.read
                    end
                rescue Exception => e
                    Deplate::DeplateForTemplates.log([e.message], :error, @source)
                    @template = ''
                end
            else
                Deplate::DeplateForTemplates.log(['Template not found', file], :error, @source)
            end
        else
            Deplate::DeplateForTemplates.log('No template defined', :error, @source)
        end
    end
    
    def fill_in(deplate, args={})
        @deplate  = deplate
        @output   = args[:output]
        @pre      = args[:pre]
        @body     = args[:body]
        @post     = args[:post]
        @source   = args[:source]
        @consumed = {
            :pre  => [],
            :body => [],
            :post => [],
        }
        @keep_whitespace = args.has_key?(:keep_whitespace) ? args[:keep_whitespace] : true
        case deplate.variables['template_version']
        when '1'
            fill_in_1
        else
            fill_in_2
        end
    end
    
    def fill_in_2
        if @@deplate_for_template
            d = @@deplate_for_template
        else
            d = @@deplate_for_template = Deplate::DeplateForTemplates.new('', @deplate_options)
            d.reset(true)
            d.push_input_format('template')
        end
        keep_whitespace  = d.options.keep_whitespace
        master           = d.options.master
        template_manager = d.options.template_manager
        begin
            d.reset
            d.variables    = @deplate.variables.dup
            # d.doc_services = @deplate.doc_services
            d.set_all_clips(@deplate.get_unprocessed_clips)
            d.options.template_manager    = self
            d.options.keep_whitespace     = @keep_whitespace
            d.options.master              = @master
            d.options.content_output      = @output
            d.options.content_pre_matter  = @pre
            d.options.content_body        = @body
            d.options.content_post_matter = @post
            @mingled = {}
            if @source
                ln = @source.begin
                fn = @source.file
            else
                ln = nil
                fn = nil
            end
            rv = [d.printable_strings(@template, ln, fn)]
            return rv
        ensure
            d.options.keep_whitespace  = keep_whitespace
            d.options.master           = master
            d.options.template_manager = template_manager
        end
    end
    
    def fill_in_1
        accum     = []
        template  = @template
        for key in @@templateKeys
            loop do
                m = send("rx_" + key).match(template)
                if m
                    accum << m.pre_match
                    template = m.post_match
                    begin
                        accum << send("process_" + key, m[3])
                    rescue Deplate::TemplateError
                        Deplate::DeplateForTemplates.log(["Template definition error", m[0]], :error, @source)
                    rescue Exception => err
                        Deplate::DeplateForTemplates.log(["Template error", m[0], err], :error, @source)
                    end
                else
                    accum << template
                    break
                end
            end
            template = accum.join
            accum = []
        end
        
        template.gsub!(/\\([{}])/, "\\1")
        return [template]
    end

    def template_get_content(type, ranges)
        case type
        when :pre
            content = @pre
        when :post
            content = @post
        when :body
            content = @body
        end

        acc = []
        cnt = content.dup
        for r in @consumed[type]
            cnt[r] = nil
        end
        add, del = gen_range(ranges)
        if add.empty?
            for i in del
                cnt[i] = nil
            end
            acc = cnt
        else
            @consumed[type] += add
            for i in add
                acc << cnt[i]
            end
        end

        return acc.flatten.compact.join("\n")
    end
    
    def gen_range(string)
        add = []
        del = []
        if string and !string.empty?
            for i in string.split(/\s+/)
                n = i.split(/\.\./).collect do |s|
                    negative = s =~ /^-/
                    s = s[1..-1] if negative
                    unless s =~ /^\d+$/
                        s = @deplate.slot_names[s.intern]
                        if s == 0
                            Deplate::DeplateForTemplates.log("Slot is zero, which is most likely an error", :anyway, @source)
                        end
                    end
                    s = s.to_i
                    negative ? -s : s
                end
                a, b, rest = n
                if rest
                    Deplate::DeplateForTemplates.log(["Bad range definition", i], :error, @source)
                else
                    if b == 0
                        b = 100
                    end
                    if a < 0
                        arr = del
                    else
                        arr = add
                    end
                    case n.size
                    when 1
                        arr << a.abs
                    when 2
                        arr << Range.new(a.abs, b.abs)
                    else
                        Deplate::DeplateForTemplates.log(["Bad range definition", i], :error, @source)
                    end
                end
            end
        end
        return add.compact, del.compact
    end


    def rx_pre
        /^[ \t]*#(PREMATTER)(:\s*([^}\s]+)\s*)?$/
    end
    def process_pre(arg)
        template_get_content(@pre, arg)
    end

    def rx_post
        /^[ \t]*#(POSTMATTER)(:\s*([^}\s]+)\s*)?$/
    end
    def process_post(arg)
        template_get_content(@post, arg)
    end

    def rx_body
        /^[ \t]*#(BODY)(:\s*([^}\s]+)\s*)?$/
    end
    def process_body(arg)
        template_get_content(@body, arg)
    end

    def rx_doc
        /\{(doc)(:\s*([^}\s]+)\s*)\}/
    end
    def process_doc(arg)
        if arg
            @deplate.variables[arg]
        else
            raise Deplate::TemplateError.new
        end
    end

    def rx_ARG
        /^[ \t]*#(ARG)(:\s*([^}\s]+)\s*)?$/
    end
    def process_ARG(arg)
        if arg
            text = @deplate.variables[arg]
            if text
                return @deplate.printable_strings(text, @source.begin, @source.file)
            end
        end
        raise Deplate::TemplateError.new
    end
    
    def rx_arg
        /\{(arg)(:\s*([^}\s]+)\s*)\}/
    end
    # alias :process_arg :process_doc
    def process_arg(arg)
        if arg
            text = @deplate.variables[arg]
            if text
                container = @container || Deplate::PseudoContainer.new(@deplate, :source => @source)
                return @deplate.parse_and_format(container, text)
            end
        end
        raise Deplate::TemplateError.new
    end

    def rx_clip
        /\{(get)(:\s*([^}\s]+)\s*)\}/
    end
    def process_clip(arg)
        if arg
            c = @deplate.get_clip(arg)
            if c
                return c.elt
            end
        end
        raise Deplate::TemplateError.new
    end
end

