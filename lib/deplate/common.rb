# encoding: ASCII
# common.rb -- The base class for deplate building blocks
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     02-Aug-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.913
# 
# = Description:
# Misc classes

# require 'forwardable'

module Deplate::CommonGround
    #### pointer to the master deplater
    attr_accessor :deplate
    attr_writer   :container
    attr_accessor :indentation
    attr_accessor :indentation_level
    attr_accessor :args
    attr_accessor :styles
    attr_writer   :doc_type
    attr_writer   :doc_slot
    attr_accessor :keep_whitespace
    attr_accessor :match
    attr_accessor :level_as_string
    attr_accessor :level_as_list
    attr_accessor :level
    attr_reader :prototype

    #### the element's parsed value
    attr_accessor :elt
    attr_accessor :text
    attr_accessor :source
    attr_accessor :prologue
    attr_accessor :epilogue
    # attr_accessor :expected
    
    def initialize(deplate, args={})
        @deplate         = deplate
        # @args          = {:class => self.class, :self => self, :deplate => deplate}
        @args            = args[:args] || {:self => self, :deplate => deplate}
        if (cn = self.class.name)
            cn = cn.split(/::/)
            if cn[0] == 'Deplate'
                acc = []
                cn[-2..-1].each do |cnpart|
                    acc << cnpart
                    globalargs = @deplate.variables["$#{acc.join}"]
                    if globalargs
                        @args.merge!(globalargs) {|k,o,n| o}
                    end
                end
            end
        end
        self.level_as_string = args[:level_as_string] || deplate.get_current_heading
        @heading         = deplate.current_heading_element
        @level_as_list   = args[:level_as_string] || deplate.current_heading.dup
        @elt             = args[:elt]      || nil
        @text            = args[:text]     || nil
        @styles          = args[:styles]   || []
        @source          = args[:source]   || nil
        @expected        = args[:expected] || nil
        @container       = args[:container]       || nil
        @prologue        = args[:prologue]        || []
        @epilogue        = args[:epilogue]        || []
        @can_be_labelled = args[:can_be_labelled] || true
        @keep_whitespace = args[:keep_whitespace] || false
        @doc_slot        = args[:doc_slot]        || nil
        @doc_type        = args[:doc_type]        || nil
    end
 
    def container
        if @container
            return @container.container || @container
        else
            return nil
        end
    end
   
    def top_container
        c = container
        return c && c.top_heading
    end

    def heading_level
        @heading && @heading.level_as_string
    end

    def update_args(opts={})
        update_styles
        update_id(opts)
    end

    def update_styles(styles=nil)
        styles ||= @args['style'] || []
        case styles
        when String
            styles = Deplate::Core.split_list(styles, ',', ';', @source)
        end
        if @deplate.variables['styledTags']
            tags = @args['tag']
            if tags
                tags = Deplate::Core.split_list(tags, ',', nil, @source)
                tags.map! {|t| "TAG#{t}"}
                styles += tags
            end
        end
        if styles and !styles.empty?
            @styles += styles
            @styles.uniq!
        end
    end
    alias :push_styles :update_styles

    def update_id(opts={})
        my_id = @args['id']
        if my_id and my_id != @args[:id]
            aid = @args[:id]
            @label << aid if aid
            @args[:id] = my_id
            if block_given?
                yield(my_id)
            end
        end
    end

    def tagged_as?(*tag)
        tags = @args['tag']
        if tags
            tags = Deplate::Core.split_list(tags, ',', nil, @source)
            return tags.any? {|t| tag.include?(t)}
        end
        false
    end

    def inlay?
        args['inlay']
    end

    def get_explicit_id(args=@args)
        args[:id] || args['id']
    end
    module_function :get_explicit_id
    
    def get_id
        # get_explicit_id || @label[0]
        get_explicit_id
    end
    
    def styles_as_string(sep=' ')
        if @styles.empty?
            nil
        else
            @styles.join(sep)
        end
    end

    def can_be_labelled
        @can_be_labelled && doc_type == :body
    end

    def log(text, condition=nil)
        @deplate.log(text, condition, @source)
    end

    def match_expected(expected=nil, invoker=self)
        if kind_of?(Deplate::Regions::Inlatex)
            return
        elsif expected
            if defined?(invoker.prototype)
                cc = element_or_particle(invoker.prototype || self)
                cl = invoker.prototype.class
            else
                cc = expected
                cl = self.class
            end
            unless kind_of?(expected) or expected != cc
                invoker.log(['Expected something of a different class', expected, cl, invoker.class], :error)
            end
        # else
            # invoker.log('Neither element nor particle', :anyway)
        end
    end
    
    def element_or_particle(obj)
        if obj.kind_of?(Deplate::Element::Clip)
            obj = obj.elt.first
        end
        for c in [Deplate::Element, Deplate::Particle]
            if obj == c or obj === c or obj.kind_of?(c)
                return c
            end
        end
        log(['Neither block element nor inline text particle', self.class, obj], :error)
        return nil
    end
    
    def doc_slot(default=:body, overwrite=false)
        if (overwrite and default) or !@doc_slot
            if @args['slot']
                @doc_slot = @args['slot']
            else
                @doc_slot = default
            end
        end
        return @doc_slot
    end
   
    def doc_type(default=:body, overwrite=false)
        if (overwrite and default) or !@doc_type
            @doc_type = @args['type'] || default
        end
        return @doc_type
    end
   
    def output(*body)
        @deplate.formatter.output(self, *body)
    end

    def output_preferably_at(type, slot, *body)
        @deplate.formatter.output_at(doc_type(type), doc_slot(slot), *body)
    end

    def output_at(type, slot, *body)
        @deplate.formatter.output_at(type, slot, *body)
    end

    def warn_unpexpected(expected, got)
        msg = 'Expected %s but got %s' % [expected, got]
        if @invoker
            @invoker.log(msg, :error)
        else
            Deplate::Core.log(msg, :error, @source)
        end
    end
    
    def format_element(agent, *args)
        return @deplate.formatter.format_element(agent, *args)
    end

    def plain_caption?
        @deplate.variables['headings'] == 'plain' or @args['plain']
    end

    def output_file_name(args={})
        obj      = args[:object] || self
        label    = args[:label]
        relative = args[:relative]
        basename = args[:basename]
        level_as_string = args[:level_as_string]
        if level_as_string
            rv = @deplate.file_name_by_level(level_as_string)
        elsif label
            rv = @deplate.get_filename_for_label(self, label) || ''
        else
            if obj.kind_of?(Deplate::BaseParticle) or obj.kind_of?(Deplate::BaseParticle)
                obj = obj.container
            end
            if obj.kind_of?(Deplate::BaseElement)
                th = obj.top_heading
                rv = th.destination
            end
        end
        if rv
            if basename
                return File.basename(rv)
            elsif relative == ''
                return File.basename(rv)
            elsif relative
                out = relative.output_file_name
                if out == rv
                    return ''
                else
                    dir = File.dirname(out)
                    return @deplate.relative_path(rv, dir)
                end
            else
                return rv
            end
        else
            log(['Internal error in #output_file_name', obj.class.name], :error)
            raise Exception
        end
    end

    def labels_sans_id
        id  = get_id
        lbl = @label.dup
        lbl.delete(id)
        lbl
    end
    
    def output_location(args={})
        location = [output_file_name(args)]
        id = get_id
        location << id if id
        location.join('#')
    end

    def post_process_text(text, args=@args)
        sub  = args['sub'] || args['s']
        if sub
            sep = sub[0..0]
            rx, rp = sub[1..-1].split(Regexp.new(Regexp.quote(sep)))
            text.gsub!(Regexp.new(rx), rp)
        end
        tr = args['tr']
        if tr
            sep = tr[0..0]
            rx, rp = tr[1..-1].split(Regexp.new(Regexp.quote(sep)))
            text.tr!(rx, rp)
        end
        if args['upcase']
            text.upcase!
        end
        if args['downcase']
            text.downcase!
        end
        if args['capitalize']
            text.capitalize!
        end
        text
    end
    module_function :post_process_text

    def filter_template(template, vars=nil, args={})
        d = args[:deplate]   ||@deplate
        v = vars || d.variables
        s = args[:source]    || @source
        c = args[:container] || @container || self
        t = Deplate::Template.new(:template  => template,
                                  :source    => s,
                                  :container => c)
        Deplate::Define.let_variables(d, v) do
            t = t.fill_in(d, :source => s)
        end
        t
    end
end


module Deplate::CommonParticle
    attr_accessor :current_heading
    attr_reader   :context

    def top_heading
        @container.top_heading
    end

    def destination
        @container.destination
    end
   
    def plain_text(*args)
        @deplate.formatter.plain_text(*args)
    end

    def format_particle(agent, *args)
        return @deplate.formatter.format_particle(agent, *args)
    end

    def format_as_string
        # <+TBD+>: Doesn't work because the particles don't give info 
        # about their formatting method
        # @deplate.formatter.format_particle_as_string(self)
    end
end


module Deplate::CommonElement
    attr_accessor :top_heading
    #### accumulated lines
    attr_accessor :accum
    attr_reader :regNote
    attr_accessor :indent

    def format_as_string
        klass = self.class
        fm    = klass.formatter
        if fm
            return @deplate.formatter.format_element_as_string(fm, self)
        else
            log(["Don't know how to format an object of this class", klass], :error)
        end
    end
    
    def add_metadata(source, metadata)
        if @deplate.options.metadata_model
            @registered_metadata << @deplate.get_metadata(source, metadata)
        end
    end
    
    def is_explicit?
        false
    end

    def update_id(opts={})
        super do |id|
            @deplate.add_label(self, get_explicit_id, level_as_string, :anyway => true)
        end
    end
end


class Deplate::CommonObject
    @class_attributes = {}
    @class_meta_attributes = {}

    class << self
        def class_attributes
            class_attributes_ensure
            @class_attributes
        end
        # protected :class_attributes
        
        def class_meta_attributes
            class_attributes_ensure
            @class_meta_attributes
        end
        
        def class_attributes=(value)
            class_attributes_ensure
            @class_attributes = value
        end
        protected :class_attributes=
 
        def class_attributes_ensure
            @class_attributes ||= {}
            @class_meta_attributes ||= {}
        end
        private :class_attributes_ensure
        
        def class_attribute(name, default=nil, args=nil)
            class_attributes_ensure
            @class_attributes[name] = default
            if args
                @class_meta_attributes ||= {}
                if @class_meta_attributes[name]
                    @class_meta_attributes[name].merge!(args)
                else
                    @class_meta_attributes[name] = args
                end
            end
        end

        def inherited(subclass)
            subclass.class_attributes.merge!(@class_attributes.dup) do |key, ov, nv|
            end
            subclass.class_meta_attributes.merge!(@class_meta_attributes.dup) do |key, ov, nv|
            end
        end
            
        def method_missing(method, *args)
            # p "DBG method_missing: #{method} #{args}"
            class_attributes_ensure
            method_s = method.to_s
            if method_s =~ /=$/
                method_s = method_s[0..-2]
                method_y = method_s.intern
                setter   = true
            else
                method_y = method
                setter   = false
            end
            if @class_attributes.keys.include?(method_y)
                pre = "hook_pre_#{method}"
                if respond_to?(pre)
                    send(pre, *args)
                end
                if setter
                    if args.size > 1
                        raise "Wrong number of arguments: #{method} #{args}"
                    end
                    rv = @class_attributes[method_y] = args[0]
                else
                    rv = @class_attributes[method_y]
                end
                post = "hook_post_#{method}"
                if respond_to?(post)
                    send(post, *args)
                end
                # p "DBG method_missing => #{rv}"
                return rv
            else
                super
            end
        end

        def respond_to?(symbol, *args)
            class_attributes_ensure
            super or @class_attributes.keys.include?(symbol)
        end
    end
end


class Deplate::Base <  Deplate::CommonObject
    include Deplate::CommonGround

    class << self
        def set_rx(rx)
            self.rx = rx
        end

        def def_get(name, arg=nil)
            mname = "get_#{name}"
            case arg
            when Array
                define_method(mname) do 
                    for i in arg
                        rv = @match[i]
                        return rv if rv
                    end
                end
            when Proc
                define_method(mname, arg)
            when Numeric
                define_method(mname) {@match[arg]}
            else
                define_method(mname) {nil}
            end
        end
        
        def set_formatter(formatter, alt=false)
            if alt
                self.formatter2 = formatter
            else
                self.formatter = formatter
            end
        end
    end

    def label_mode
        self.class.label_mode
    end

    def pop(array)
        array.pop
    end

    def exclude?(filter, container=nil)
        unless filter
            return false
        end
        tags = @args['tag'] || 'any'
        taglist = Deplate::Core.split_list(tags)
		if container and (tags = @container.args['tag'])
			taglist += Deplate::Core.split_list(tags)
		end
        if (globaltags = @deplate.variables['tag'])
            taglist += Deplate::Core.split_list(globaltags)
        end
        Deplate::Core.split_list(filter).each do |ftag|
            if ftag == 'any' and taglist.empty?
                return false
            else
                taglist.each do |tag|
                    if ftag == tag
                        return false
                    end
                end
            end
        end
        return true
    end

    class_attribute :formatter
    class_attribute :formatter2
    class_attribute :rx
    class_attribute :indentation_mode, :auto
    class_attribute :label_mode
    class_attribute :volatile, false
end


class Deplate::BaseElement < Deplate::Base
    include Deplate::CommonElement
end


class Deplate::BaseParticle < Deplate::Base
    class_attribute :pre_condition, nil
    include Deplate::CommonParticle
end

