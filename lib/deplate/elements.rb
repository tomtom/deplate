# encoding: ASCII
# elements.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     26-Mär-2004.
# @Last Change: 2009-12-05.
# @Revision:    0.4610

require "deplate/abstract-class"

class Deplate::DontFormatException < Exception
end

Deplate::CaptionDef = Struct.new('DeplateCaptionDef', :elt, :args, :source)

# Deplate::Elements are text entities at line or paragraph level.
class Deplate::Element < Deplate::BaseElement
    @@elements = []

    @@accumulate_pre  = {}
    @@accumulate_post = {}
 
    #### attached labels
    attr_accessor :label
    #### an attached caption (for Table etc.)
    attr_reader   :caption
    attr_accessor :captionOptions
    #### is this element in one-line format?
    attr_accessor :multiliner
    #### end pattern
    attr_reader   :endRx
    #### the element's level of indentation or whatever
    attr_accessor :level_heading, :top_heading_idx
    #### an array of deferred formatting blocks
    attr_accessor :postponed_format, :postponed_preformat
    #### whether we can collapse this element with another one
    attr_accessor :collapse
    #### postponed registration of metadata
    attr_accessor :registered_metadata
    
    attr_reader :line_cont
    attr_reader :embedable

    # class methods & variables
    class << self

        def match(text)
            return self.rx.match(text)
        end

        def elements
            return @@elements
        end

        def is_volatile?(match, input)
            false
        end
     
        def register_element(c=self)
            @@elements << c
        end

        def accumulate(src, array, deplate, text, match, *args)
            Deplate::Core.log(["New element", self.name, text], :debug)
            e = self.new(deplate, src, text, match, *args)
            if e
                array << e
            end
        end
    
        def accumulate_pre(klass, format, &block)
            hooks = @@accumulate_pre[klass] || {}
            pre   = hooks[format] || []
            hooks[format] = pre << block
            @@accumulate_pre[klass] = hooks
        end

        def accumulate_post(klass, format, &block)
            hooks = @@accumulate_post[klass] || {}
            post  = hooks[format] || []
            hooks[format] = post << block
            @@accumulate_post[klass] = hooks
        end

        def do_accumulate(src, array, deplate, text, *args)
            run_accumulation_hooks(@@accumulate_pre[self], src, array, deplate, text, *args)
            begin
                top = array.last
                accumulate(src, array, deplate, text, *args)
                indentation  = text.gsub(/^(\s*).*$/, '\\1')
                shiftwidth   = deplate.variables['tabWidth']
                shiftwidth   = shiftwidth ? shiftwidth.to_i : 4
                indent_level = indentation.size / shiftwidth
                i = -1
                while ((e = array[i]) and (!top or e != top))
                    e.indentation       = indentation
                    e.indentation_level = indent_level
                    i -= 1
                end
            rescue Exception => e
                # p e.backtrace
                Deplate::Core.log(['Error when running command', e], :error, src)
            end
            run_accumulation_hooks(@@accumulate_post[self], src, array, deplate, text, *args)
        end

        def run_accumulation_hooks(all_hooks, src, array, deplate, *args)
            if all_hooks
                klass = deplate.formatter.class
                begin
                    hooks = all_hooks[klass]
                    if hooks
                        for block in hooks
                            block.call(src, array, deplate, *args)
                        end
                    end
                    klass = klass.superclass
                end until klass === Module
            end
        end
        
        def get_date(arg, args)
            case arg
            when 'now', '', nil
                return Time.new.asctime
            when 'time'
                return Time.new.strftime('%X')
            when 'today'
                return Time.new.strftime('%d. %b %Y')
            when 'month'
                return Time.new.strftime('%B %Y')
            when 'year'
                return Time.new.strftime('%Y')
            when 'none', 'nil'
                return ''
            # when '', nil
            #     return ''
            else
                return Time.new.strftime(arg)
            end
        end
    end

    def initialize(deplate, src, text, match, *args)
        super(deplate)
        @multiliner  = false
        @source      = src
        @text        = text
        @match       = match
        @endRx       = nil
        @fmx         = nil
        @label       = []
        @collapse    = false
        @caption     = nil
        @container   = nil
        @line_cont   = true
        @embedable   = true
        @postponed_format    = []
        @postponed_preformat = []
        @registered_metadata = []
        
        @level = get_level if respond_to?(:get_level)
        @accum = respond_to?(:get_text) ? [get_text] : []
        @accum.compact!

        set_instance_top

        @deplate.call_methods_matching(self, /^hook_pre_setup_/)
        setup(*args)
        @deplate.call_methods_matching(self, /^hook_post_setup_/)
    end

    def set_instance_top
        @top_heading_idx     = @deplate.top_heading_idx
        @top_heading         = @deplate.top_heading_by_idx(@top_heading_idx)
        @level_heading       = @deplate.current_heading.dup
        self.level_as_string = @deplate.get_current_heading
    end

    def setup
    end

    def level_as_string
        @level_as_string
    end
    
    def level_as_string=(val)
        @args[:level_as_string] = val
        @level_as_string = val
    end
   
    def put_label(lab, anyway=false)
        if lab
            for l in lab.compact
                # or @deplate.label_aliases.include?(l)
                if anyway or !@label.include?(l)
                    @label << l
                    @deplate.add_label(self, l, level_as_string, :anyway => anyway)
                end
            end
        end
    end
    
    def collapsable?(other)
        return @collapse && other.collapse && self.class == other.class
    end
   
    def drop?(filter=nil)
        return @collapse == :drop || (filter && exclude?(filter))
    end
    
    def unify(other)
        if other.drop?
            other.container = self
            return true
        elsif collapsable?(other)
            unify_now(other)
            other.container = self
            return true
        else
            return false
        end
    end

    def <<(line)
        @accum << line
    end

    def_abstract :push_match

    def to_be_continued?(line, klass, match)
        @multiliner && (klass == @deplate.input.comment_class || klass.nil?)
    end
    
    # compile the accumulated lines in @accum & put the result into @elt
    def finish
        elt  = join_lines(@accum)
        @elt = [ @deplate.parse(self, elt) ]
        return self
    end

    def finished?
        return defined?(@elt) && @elt != nil
    end

    def join_lines(accum)
        if @deplate.options.keep_whitespace
            return accum.join("\n")
        else
            return accum.collect {|l| l.strip}.join(' ')
        end
    end

    def process
        process_etc
        process_particles do |e|
            printable_particles(e)
        end
        return self
    end

    def printable_particles(e)
        if e.kind_of?(String)
            ### <+TBD+> This actually is more of an error and shouldn't be
            e
        else
            rv = e.collect do |p|
                case p
                when Array
                    printable_particles(p)
                else
                    # <+TBD+> begin
                    # p.container = self
                    p.process
                    # rescue Exception => e
                    # puts e.backtrace.join("\n")
                    # raise
                    # end
                    p.elt
                end
            end
            @deplate.join_particles(rv)
        end
    end
    
    def print
        unless @args['swallow']
            for block in @postponed_preformat
                block.call(self)
            end
            output(format_current)
            for block in @postponed_format
                block.call(self)
            end
        end
    end

    def format_contained(container, *args)
        unless @postponed_preformat.empty?
            container.postponed_preformat |= @postponed_preformat
        end
        unless @postponed_format.empty?
            container.postponed_format |= @postponed_format
        end
        format_current(*args)
    end

    def format_current(formatting_method=nil)
        formatting_method ||= self.class.formatter
        if formatting_method
            case formatting_method
            when Array
                for fm in formatting_method
                    @elt = format_element(fm, self)
                end
                elt = @elt
            when Symbol
                elt = format_element(formatting_method, self)
            else
                log(['Internal error', 'format_current', self.class.name, formatting_method],
                    :error)
            end
        elsif self.respond_to?(:format_special)
            elt = format_special
        else
            elt = @deplate.formatter.format_unknown(self)
        end
        if elt
            acc = []
            pre = format_prologue and acc << pre
            acc << elt
            post = format_epilogue and acc << post
            label_accum(acc, formatting_method) if doc_type == :body
            rv = @deplate.formatter.join_blocks(acc.compact)
        else
            rv = nil
        end
        register_metadata
        return rv
        # rescue Exception => e
        #     log(["Formatting failed", self.class.name, e], :error)
        #     format_element(:format_unknown, self)
        # end
    end
   
    def register_metadata
        @deplate.output.merge_metadata(@registered_metadata)
        for l in @label
            m = @deplate.get_metadata(@source, 
                                      'type' => 'label', 
                                      'name' => l
                                     )
            @deplate.output.push_metadata(m)
        end
    end

    def label_accum(out, formatting_method)
        fmt = @deplate.formatter
        if formatting_method and fmt.label_once.include?(formatting_method)
            l = format_element(:format_label, self, :once)
            out.unshift(l) unless l.empty?
        elsif fmt.label_delegate.include?(formatting_method)
        else
            case self.label_mode || fmt.label_mode
            when :once
                l = format_element(:format_label, self, :once)
                out.unshift(l) unless l.empty?
            when :before
                l = format_element(:format_label, self, :before)
                out.unshift(l) unless l.empty?
            when :after
                l = format_element(:format_label, self, :after)
                out.push(l) unless l.empty?
            when :delegate, :self, :none
            else
                lb = format_element(:format_label, self, :before)
                la = format_element(:format_label, self, :after)
                out.unshift(lb) unless lb.empty?
                out.push(la) unless la.empty?
            end
        end
    end
    
    def format_prologue
        @prologue.empty? ? nil : @prologue
    end

    def format_epilogue
        @epilogue.empty? ? nil : @epilogue
    end

    def destination
        if @top_heading and @top_heading != self
            @top_heading.destination
        else
            @destination
        end
    end
  
    def register_caption
        # log(["Cannot attach caption to", self.class.name], :error)
    end

    def set_caption(captiondef, quiet=false, extended_syntax=false)
        if @caption
            log('Element already has a caption', :error) unless quiet
        else
            self.level_as_string = @deplate.get_current_heading
            captiondef.elt   = @deplate.parse_with_source(captiondef.source, 
                                                          captiondef.elt,
                                                          extended_syntax)
            @caption = captiondef
            if respond_to?(:register_caption)
                register_caption
            end
        end
    end

    def to_plain_text
        @accum.join("\n")
    end

    def element_caption
        @caption ? @caption.elt : elt_as_caption
    end
    
    def elt_as_caption
        @elt
    end

    def register_in_listing(list, args={})
        @deplate.options.listings.push(list, self)
        
        en = @deplate.options.listings.get_prop(list, 'entity') || list
        # nn = @deplate.get_numbering_mode(en, 2)
        # nn = nil if nn == 0
        cn = @deplate.options.listings.get_prop(list, 'counter') || list
        # self.level_as_string = @deplate.options.counters.increase(cn, :container => self, :to_s => true, :level => nn)
        self.level_as_string = @deplate.options.counters.increase(cn, :container => self, :to_s => true)
        prefix = @deplate.options.listings.get_prop(list, 'prefix') || list
        label  = @deplate.elt_label(prefix, level_as_string)
        @label << label
        @args[:id] ||= label

        @registered_metadata << @deplate.get_metadata(@source,
                                                      'type' => list,
                                                      'name' => element_caption,
                                                      'id'   => get_id
                                                     )
    end

    def process_etc
        if !@caption and @args['caption']
            # puts caller[0..10].join("\n")
            # log(['DEBUG: Too late: Add caption', @args['caption']], :error)
            log(['Add caption', @args['caption']])
            # caption = @deplate.parse(self, @args['caption'])
            caption = @args['caption']
            set_caption(Deplate::CaptionDef.new(caption, @args, @source))
        end
        if defined?(@caption) && @caption
            elt = @caption.elt.collect {|p| p.process; p.elt}
            @caption.elt = @deplate.join_particles(elt)
        end
    end
    alias process_options process_etc

    def unify_now(other)
        unify_elt(other)
        unify_props(other)
    end

    def unify_props(other)
        if !level_as_string and other.level_as_string
            self.level_as_string = other.level_as_string
        end
        l = [other.args['id'], other.args[:id], *other.label]
        l.compact!
        l.uniq!
        put_label(l, true)
        unify_args(other.args)
        # p "DBG", self.class, other.class, @args.keys, other.args.keys
        @level          ||= other.level
        @source.begin   ||= other.source.begin
        @source.end       = other.source.end if other.source.end
        @indentation    ||= other.indentation
        @indentation_level ||= other.indentation_level
        @captionOptions ||= other.captionOptions
        if !@caption
            cap = @args['caption']
            if cap
                set_caption(Deplate::CaptionDef.new(cap, @args, @source))
            elsif other.caption
                @caption = other.caption
            end
        end
        if other.styles
            update_styles(other.styles)
        end
    end
   
	def unify_args(args)
        @args.update(args) do |k, o, n|
            case k
            when 'tag'
                [o, n].join(',')
            else
                n
            end
        end
		update_args
	end

    def unify_elt(other)
        if @elt.nil?
            @elt = other.elt
        elsif !other.elt.nil?
            @elt += other.elt
        end
    end

    def container=(element)
        @container = element
        # @args      = element.args
        @args.update(element.args)
        @postponed_format    = element.postponed_format
        @postponed_preformat = element.postponed_preformat
    end

    def get_indent(text)
        text = expand_tab(text)
        /^\s*/.match(text)[0]
    end

    def expand_tab(text)
        tabwidth = @deplate.variables['tabwidth'] || 4
        accum    = []
        loop do
            m = /\t/.match(text)
            if m
                pre  = m.pre_match
                text = m.post_match
                add  = tabwidth - pre.size % tabwidth
                accum << pre + (' ' * add)
            else
                return accum.join + text
            end
        end
        return text
    end
  
    # call block on all text particles in the current element
    def process_particles(&block)
        if @elt
            @elt = (@elt.collect(&block)).join
        else
            # p "DBG", @accum
            # puts caller.join("\n")
            log(['Internal error: No @elt', self.class], :error)
            @elt = ''
        end
    end
    alias process_elements process_particles

    def register_figure
        register_in_listing('lof')
    end
    
    def register_table
        register_in_listing('lot')
    end
end


class Deplate::Element::PseudoElement < Deplate::Element

    def initialize(deplate, src, container, &formatter)
        super(deplate, src, text, [])
        @formatter = formatter
        @container = container
    end

    def process
        @container.process_etc
        # @container.process
        self
    end

    def format_special
        return @formatter.call(self)
    end

end


# Don't register Paragraph in @@elements -- it's assigned if nothing else 
# matches
class Deplate::Element::Paragraph < Deplate::Element
    set_formatter :format_paragraph
    set_rx(/^([[:blank:]]*)(.+)[[:blank:]]*$/)
    def_get :level, lambda {get_indent(@match[1]).size}
    def_get :text, lambda {@deplate.options.keep_whitespace ? @match[0] : @match[2]}

    class << self
        def from_text(deplate, src, text)
            m = self.rx.match(text)
            self.new(deplate, src, text, m)
        end
    end

    def setup
        @multiliner = true
    end
end


class Deplate::Element::Comment < Deplate::Element::Paragraph
    register_element
    # set_rx(/^\s*(%+)[[:blank:]]*(.*)$/)
    set_rx(/^\s*(%+)\s*(.*)$/)
    # def_get :level, lambda {@match[1].size}
    def_get :level, lambda {get_marker.size}
    def_get :marker, 1
    def_get :text, 2

    # disappear unless commentsShow is set
    class << self
        def accumulate(src, array, deplate, text, match)
            m = deplate.variables['commentsShow']
            if m
                e = self.new(deplate, src, text, match)
                if e and (m == true or e.get_marker == m)
                    e.update_styles('sourceComment')
                    array << e
                    return
                end
            end
            Deplate::Core.log(["Hide comment", text], :debug)
        end

        def show_comment?(deplate, text)
            m = deplate.variables['commentsShow']
            return m && (m == true || text =~ Regexp.new('^\s*' + Regexp.escape(m)))
        end
    end

    def setup
        if @deplate.variables['commentsShow']
            @multiliner = true
        else
            @collapse = true
        end
    end

    def <<(line)
        m = self.class.rx.match(line)
        @accum << m[2]
    end
end


class Deplate::Element::Note < Deplate::Element
    register_element
    set_formatter :format_note
    set_rx(/^([[:blank:]]+)([#!?+]{3,3})\s+(.*)$/)
    def_get :level, lambda {expand_tab(@match[1]).size}
    def_get :marker, lambda {@match[2][0..0]}
    def_get :text, 3

    attr_reader :marker

    def setup
        @multiliner = true
        @marker     = get_marker
    end

    def finish
        rv = super
        case @marker
        when '+'
            log(['TODO', @accum.join(' ')], :anyway)
        end
        return rv
    end
    
    def to_be_continued?(line, klass, match)
        indent = get_indent(line).size
        return indent >= @level
    end
end


Deplate::ListItem   = Struct.new('DeplateListItem', :item, :body, :listtype, :type,
                                 :level, :max, :explicit, :label, :style, :opts,
                                 :preformatted)

class Deplate::List < Deplate::Element
    set_formatter :format_list
    class_attribute :listtype
    # class_attribute :not_embedable, []

    def_get :opts
    def_get :level, lambda {expand_tab(@match[2]).size}
    def_get :level_max, lambda {expand_tab(@match[1]).size}
    def_get :item, 3
    def_get :text, 4

    attr_reader :levelRange, :item, :oitem
   
    def setup
        @multiliner = true
        @collapse   = true
        @itemopts   = get_opts
        if self.instance_of?(Deplate::List::Description)
            @levelMax = @level + (@deplate.variables['tabwidth'] || 4)
        else
            @levelMax = get_level_max
        end
        @oitem = @item = get_item
    end

    def collapsable?(other)
        if other.kind_of?(Deplate::List)
            return true
        elsif other.kind_of?(Deplate::Element::Paragraph)
            return @elt.find do |i|
                continuation_level_ok?(other.level, i.level, i.max)
            end
        elsif other.kind_of?(Deplate::Element::Whitespace)
            return true
        elsif indentation_level_ok?(other) and other.embedable
            # and !self.class.not_embedable.include?(other.class)
            return true
        else
            return false
        end
    end

    def pop(array)
        if @elt.empty?
            array.pop
        else
            @elt.pop
        end
    end

    def unify_now(other)
        # if other.exclude?(@deplate.variables['efilter'])
            # Basically, this should happen in Input
        if other.kind_of?(Deplate::Element::Paragraph)
            @elt << Deplate::ListItem.new([], other.elt.flatten, @elt.last.listtype, 
                                        "Paragraph", other.level, other.level, 
                                         other.is_explicit?, other.label,
                                         other.class.name)
            other.label = []
            unify_props(other)
        elsif other.kind_of?(Deplate::Element::Whitespace)
        elsif other.kind_of?(Deplate::List)
            super
        else
            e = @elt.last
            unless e.type == 'Container' and e.body.unify(other)
                # unify_props(other)
                l = other.level
                unless l
                    l   = e.level if e
                    l ||= level
                end
                @elt << Deplate::ListItem.new([], other, @elt.last.listtype, 
                                              "Container", l, l, 
                                              other.is_explicit?, other.label,
                                              other.class.name)
            end
        end
    end

    def to_be_continued?(line, klass, match)
        linelevel = get_indent(line).size
        klass.nil? && continuation_level_ok?(linelevel, @level, @levelMax)
    end

    def continuation_level_ok?(otherLevel, thisLevel, thisMaxLevel)
        # return thisLevel <= otherLevel && otherLevel <= thisMaxLevel
        return thisLevel <= otherLevel
    end
    
    def indentation_level_ok?(other)
        return indentation <= other.indentation
    end
    
    def finish
        finish_item
        finish_elt
        @label = []
        return self
    end

    def finish_item
		# item  = is_explicit? ? @item : (@args['itemLabel'] || @item)
        @item = @deplate.parse(self, @item)
    end

    def finish_elt
        accum  = @deplate.parse(self, @accum.join(" "))
        type   = self.class.listtype
        @elt   = [Deplate::ListItem.new(@item, accum, type, type, @level, 
                                        @levelMax, is_explicit?, @label,
                                        type, @itemopts)]
    end
    
    def process_particles(&block)
        @elt.each do |e|
            e.item = block.call(e.item)
            case e.type
            when 'Container'
                # <+TBD+> This doesn't work for all elements (e.g. 
                # volatile elements)
                # e.body.process_particles(&block)
                e.body = e.body.process
            else
                e.body = block.call(e.body)
            end
        end
    end
end


class Deplate::List::Ordered < Deplate::List
    register_element
    set_rx(/^(([[:blank:]]+)([0-9]+\.|[#\@?]\.?|[a-zA-Z?]\.)[[:blank:]]+)(.+)$/)
    self.listtype = "Ordered"
    
    def is_explicit?
        if @oitem =~ /^[0-9a-zA-Z]+\.$/
            return true
        else
            return false
        end
    end
end


class Deplate::List::Itemize < Deplate::List
    register_element
    set_rx(/^(([[:blank:]]+)([-+*])[[:blank:]]+)(.+)$/)
    self.listtype = "Itemize"
end


class Deplate::List::Description < Deplate::List
    register_element
    set_rx(/^(([[:blank:]]+)(.+?)[[:blank:]]+::[[:blank:]])(.*)$/)
    self.listtype = "Description"
end


class Deplate::List::Task < Deplate::List
    register_element
    set_rx(/^(([[:blank:]]+)#(([0-9][A-Z]?|[A-Z][0-9]?)([[:blank:]]+(_|x|x?[0-9-]+%?))?|(_|x|x?[0-9-]+%?)[[:blank:]]+([0-9][A-Z]?|[A-Z][0-9]?)))[[:blank:]]+(.*)$/)
    self.listtype = 'Task'
    def_get :item, lambda {[@itemopts[:priority], @itemopts[:category]].join}
    def_get :text, 9
    
    attr_accessor :task

    def finish_item
        # @item = @deplate.parse(self, @item)
    end

    def get_opts
        if defined?(@task) and @task
            return @task
        end

        item = @match[3]
        rv   = {}
        type, due = item.split(/\s+/)
        if type =~ /^(_|x|x?[\d-]+%?)$/
            type, due = due, type
        end
        
        if type =~ /^([0-9])([A-Z]?)$/
            rv[:priority] = $1
            rv[:category] = $2 unless $2.empty?
        elsif type =~ /^([A-Z])([0-9]?)$/
            rv[:priority] = $2
            rv[:category] = $1 unless $1.empty?
        else
            log(['Invalid task item', item], :error)
        end

        if due =~ /^\s*x/
            rv[:done] = true
        end
        if due =~ /^\s*x?([0-9-]+%?)/
            rv[:due] = $1
        end

        rv
    end
end


class Deplate::Element::Region < Deplate::Element
    register_element
    set_rx(/^(\s*)#([A-Z]([a-z][A-Za-z]*)?)\b(!)?(.*)(\<\<(.*)|:)\s*$/)

    class_attribute :rxi_indent, 1
    class_attribute :rxi_name,   2
    class_attribute :rxi_bang,   4
    class_attribute :rxi_args,   5
    class_attribute :rxi_endrx,  7

    def_get :name,   lambda {@match[self.class.rxi_name]}
    def_get :bang,   lambda {@match[self.class.rxi_bang]}
    def_get :args,   lambda {@match[self.class.rxi_args]}
    def_get :indent, lambda {@match[self.class.rxi_indent]}
    def_get :endrx,  lambda {
        i = self.class.rxi_endrx
        if @match[i - 1] == ":"
            /^(#{get_indent})?#End\s*$/
        else
            erx = @match[i]
            if erx =~ /\S/
                /^(#{get_indent})?#{Regexp.escape(erx)}\s*$/
            else
                /^\s*$/
            end
        end
    }

    class << self
        def pseudo_match(args)
            rv = []
            rv[rxi_indent] = args[:indent]
            rv[rxi_args]   = args[:args]
            rv[rxi_name]   = args[:name]
            rv[rxi_endrx]  = args[:endrx]
            rv[rxi_bang]   = args[:bang]
            rv
        end
    end

    attr_reader :specified, :regNote, :name
    
    def setup(name=nil, args=nil)
        @multiliner = true
        @endRx      = get_endrx
        @name       = name || get_name
        begin
            if args
              @args = args
              @regNote = ''
            else
              @args, @regNote = @deplate.input.parse_args(get_args)
            end
            @args = @args.merge(@deplate.variables["args@#{@name}"] || {})
            @args['bang'] = true if get_bang
            Deplate::Region.deprecated_regnote(self, @args, @regNote)
            region = @deplate.input.regions[@name]
            unless region
                if @deplate.formatter.matches?(@name)
                    Deplate::Core.log(["Obsolete use of native regions. Please use", "#Native fmt=#{@deplate.formatter.formatter_name}"], :error, @source)
                else
                    # We put a message to notify the user of an ignored class
                    # This should be a native class for an unused formatter
                    Deplate::Core.log(["Unknown region class", @name], :error, @source)
                end
                region = Deplate::Regions::UNKNOWN
            end
        rescue Deplate::DontFormatException
            Deplate::Core.log(["Dropping", @match[0]], nil, @source)
            region = Deplate::Regions::UNKNOWN
        end
        @specified = region.new(@deplate, @source, @text, @match, self)
        @line_cont = region.line_cont
        # @deplate.register_id(@args, @specified)
        @deplate.register_id(@args, self)
    end

    def finish
        update_region
        return @specified.finish
    end

    def finished?
        @specified.finished?
    end

    def update_region
        @specified.indentation = indentation
        @specified.indent      = get_indent
    end
end


class Deplate::Element::Command < Deplate::Element
    register_element
    set_rx(/^\s*#([A-Z]+)(!)?\s*?((\s[^:]+)?(:\s*(.+?)\s*)?)$/)
    attr :name
   
    class << self
        def is_volatile?(match, input)
            cmd = input.commands[match[1]]
            if cmd
                cmd.volatile
            else
                false
            end
        end
        
        def accumulate(src, array, deplate, text, match)
            cmd = match[1]
            Deplate::Core.log(['Command', cmd, text], :debug)
            begin
                args, text = deplate.input.parse_args(match[3])
                args = args.merge(deplate.variables["args@#{cmd}"] || {})
                args['bang'] = true if match[2]
                case cmd
                when 'IF'
                    deplate.switches << !check_switch(deplate, text)
                when 'ELSEIF'
                    if deplate.switches.empty?
                        Deplate::Core.log(['ELSEIF without IF', cmd, match[0]], :error, src)
                    else
                        case deplate.switches.last
                        when :skip
                        when true
                            deplate.switches.pop
                            deplate.switches << !check_switch(deplate, text)
                        else
                            deplate.switches.pop
                            deplate.switches << :skip
                        end
                    end
                when 'ELSE'
                    if deplate.switches.empty?
                        Deplate::Core.log(['ELSE without IF', cmd, match[0]], :error, src)
                    else
                        case deplate.switches.last
                        when :skip
                        when true
                            deplate.switches << !deplate.switches.pop
                        else
                            deplate.switches.pop
                            deplate.switches << :skip
                        end
                    end
                when 'ENDIF'
                    if deplate.switches.empty?
                        Deplate::Core.log(['ENDIF without IF', cmd, match[0]], :error, src)
                    else
                        deplate.switches.pop
                    end
                else
                    if !deplate.switches.last
                        cc = deplate.input.commands[cmd]
                        if cc
                            cc.do_accumulate(src, array, deplate, text, match, args, cmd)
                        else
                            Deplate::Core.log(['Unknown command', cmd, match[0]], :error, src)
                        end
                    end
                end
            rescue Deplate::DontFormatException
                Deplate::Core.log(['Dropping', match[0]], nil, src)
            end
        end

        # return true if the test succeeds
        def check_switch(deplate, text)
            if text =~ /^\(.*\)$/
                text = text[1..-2]
            end
            m = /^\s*([:]?\w+(\[.+?\])?)\s*((!=~|=~|==|!=)\s*(.+)\s*|!)$/.match(text)
            if m
                var = m[1]
                negate = /^no([A-Z].*)$/.match(var)
                if negate
                    var = negate[1][0..0].downcase + negate[1][1..-1]
                end
                val = m[5]
                op  = val ? m[4] : m[3]
                case val
                when 'true'
                    val = true
                when 'false'
                    val = false
                when nil
                else
                    val = Deplate::Core.remove_backslashes(val.strip)
                end
                case var
                when 'fmt'
                    vvar = deplate.formatter.formatter_name
                else
                    vvar = get_var_or_option(deplate, var)
                end
                # if vvar.nil? and val == false
                #     vvar = false
                # end
                if op == '!'
                    switch = vvar
                    if negate
                        return !switch
                    else
                        return switch
                    end
                else
                    case op
                    when '==', '!='
                        compare = Proc.new {|a, b| a == b}
                    when '=~', '!=~'
                        compare = Proc.new {|a, b| a =~ Regexp.new(b)}
                    else
                        raise 'Internal error'
                    end
                    switch = compare.call(vvar, val)
                    if op[0..0] == '!' or negate
                        return !switch
                    else
                        return switch
                    end
                end
            elsif text =~ /^\w+$/
                return get_var_or_option(deplate, text)
            else
                Deplate::Core.log(['Malformed condition', text], :error)
                return true
            end
        end

        def get_var_or_option(deplate, key)
            begin
                if deplate.is_allowed?(':') && key =~ /^:(.*)$/
                    return deplate.options.send($1)
                    # elsif deplate.variables.has_key?(key)
                else
                    return deplate.variables[key]
                end
            rescue Exception => e
                Deplate::Core.log(e, :error)
            end
            Deplate::Core.log(['Unknown variable or option', key])
            return nil
        end
    end
end


class Deplate::Element::Table < Deplate::Element
    register_element
    set_formatter :format_table
    set_rx(/^\s*(\|\|?)([[:blank:]]+.+[[:blank:]]+)\1\s*$/)

    TableRow  = Struct.new('DeplateTableRow', :high, :cols, :head, :foot, :is_ruler,
                           :from_top, :from_bottom)
    TableCell = Struct.new('DeplateTableCell', :cell, 
                           :x, :y, :from_right, :from_bottom,
                           :high, :head, :foot,
                           :span_x, :span_y, :row)

    attr_accessor :preNote, :postNote, :coordinates, 
        :contains_footnotes, :printed_header

    def setup
        @multiliner  = :match
        @collapse    = true
        high         = get_highlight
        cols         = get_cols
        cols.collect! {|t| t.strip}
        @accum       = [ TableRow.new(high, cols) ]
        @preNote     = nil
        @postNote    = nil
        @contains_footnotes = false
    end

    def to_be_continued?(line, klass, match)
        klass == self.class
    end

    def push_match(match)
        high         = get_highlight(match)
        cols         = get_cols(match)
        cols.collect! {|t| t.strip}
        @accum << TableRow.new(high, cols)
    end

    def get_highlight(match=@match)
        match[1].size == 2
    end

    def get_cols(match=@match)
        match[2].split(/[[:blank:]]\|\|?[[:blank:]]/)
    end
    
    def unify_now(other)
        super
        @contains_footnotes ||= other.contains_footnotes
    end
    
    def collapsable?(other)
        return @collapse && other.collapse && self.class == other.class
    end
   
    def finish
        @accum.each do |row|
            row.is_ruler = false
            row.cols.collect! do |c|
                case c
                when /^-+$/
                    row.is_ruler = true
                    :ruler
                when "<"
                    log(["Malformed ruler definition (<)", col.cols], :error) if row.is_ruler
                    :join_left
                when "^"
                    log(["Malformed ruler definition (^)", col.cols], :error) if row.is_ruler
                    :join_above
                when /^\s*$/
                    if row.is_ruler
                        :noruler
                    else
                        @deplate.parse(self, c)
                    end
                else
                    log(["Malformed ruler definition", c, col.cols], :error) if row.is_ruler
                    @deplate.parse(self, c)
                end
            end
        end
        @elt = @accum
        return self
    end
 
    def process_particles(&block)
        hiCol   = get_table_args("hiCol")
        hiRow   = get_table_args("hiRow")
        head    = @args["head"]
        head    = head ? head.to_i : 0
        foot    = @args["foot"]
        foot    = foot ? foot.to_i : 0
        rowmax  = @elt.size
        @coordinates = {}
        y = 0
        rown = @elt.size
        for row in @elt
            y += 1
            x  = 0
            coln = row.cols.size
            row.cols.collect! do |cell|
                x += 1
                case cell
                when :join_left
                    parent = find_parent_cell(x, y, 1, 0)
                    if parent.kind_of?(Symbol)
                    elsif parent
                        parent.span_x += 1
                    else
                        log(["Table: Cannot join with left cell", x, y], :error)
                    end
                when :join_above
                    parent = find_parent_cell(x, y, 0, 1)
                    if parent.kind_of?(Symbol)
                    elsif parent
                        parent.span_y += 1
                    else
                        log(["Table: Cannot join with above cell", x, y], :error)
                    end
                when :ruler, :noruler
                    row.is_ruler = true
                else
                    cell = TableCell.new(block.call(cell), x, y)
                    cell.from_bottom = rown - y
                    cell.from_right  = coln - x
                    cell.span_x = 1
                    cell.span_y = 1
                    cell.row    = row
                    cell.high   = check_table_opts(hiCol, x, coln)
                end
                @coordinates[[x,y]] = cell
                cell
            end
            if y <= head
                row.head = true
            elsif (rowmax - y + 1) <= foot
                row.foot = true
            elsif check_table_opts(hiRow, y, rowmax)
                row.high = true
            end
            row.from_top    = y
            row.from_bottom = rowmax - y
        end
        for row in @elt
            if row.high
                row.head = true
            else
                break
            end
        end
        for row in @elt.reverse
            if row.high and !row.head
                row.foot = true
            else
                break
            end
        end
    end

    def check_table_opts(args, nth, max)
        (nth == 1 and args.include?("first")) or 
            (nth == max and args.include?("last")) or 
            args.include?("%d" % nth)
    end
    
    def get_table_args(name)
        args = @args[name]
        args ? Deplate::Core.split_list(args, nil, nil, @source) : []
    end

    def find_parent_cell(x, y, delta_x, delta_y)
        i = 1
        loop do
            xx = x - (delta_x * i)
            yy = y - (delta_y * i)
            c = @coordinates[[xx, yy]]
            case c
            when :join_left
                return c if delta_x == 0
            when :join_above
                return c if delta_y == 0
            when :ruler, :noruler
            when nil
                return nil
            else
                return c
            end
            i += 1
        end
    end

    def unify_props(other)
        super
    end
    
    def register_caption
        register_table
    end
end


class Deplate::Element::Heading < Deplate::Element
    attr_accessor :first_top, :last_top, :top_index, :abstract
    attr_writer :destination
    
    register_element
    set_formatter :format_heading
    set_rx(/^(\*+)[[:blank:]]+(.*?)$/)
    def_get :level, lambda {@match[1].size}
    def_get :text, 2

    class << self
        def accumulate(src, array, deplate, text, match)
            Deplate::Element::PotentialPageBreak.accumulate(src, array, deplate, text, match)
            ppb = array[-1]
            super
            hd  = array[-1]
            if hd.is_top_heading?
                ppb.enabled = true
            end
        end
        
        # Programmatically markup text as heading.
        def markup(text, level=1)
            ['*' * level, text].join(' ')
        end
    end
    
    def set_instance_top
        ls = @deplate.variables['levelshift']
        if ls
             @level += ls.to_i
        end
        @deplate.increase_current_heading(self, @level)
        super
    end
    
    def setup
        @first_top   = false
        @last_top    = false
        @abstract    = nil
        @destination = @deplate.output.destination
        @top_index   = [0, 0]
        @args[:id]   = @deplate.elt_label('hd', level_as_string)
        @deplate.options.listings.push('toc', self)
        # register_in_listing('toc')
        @deplate.headings[@level_heading] = self
        update_args
    end

    def is_top_heading?
        @level <= @deplate.options.split_level
    end
    
    def update_options(args)
        @args.update(args)
        update_args
    end
    
    def update_args
        super
        register_heading
    end

    def register_heading
        sc = @args['@id'] || @args['shortcaption']
        log(['Register heading', level_as_string, sc], :debug)
        @deplate.set_top_heading(self, sc)
    end
    
    def process
        rv  = super
        url = @args['url']
        hh  = @deplate.variables['hyperHeading']
        if url and hh
            if hh == 'full'
                # <+TBD+> Extract invalid tags and move them add them to the 
                # end of the result (but this has to be done by the 
                # formatter, so well ...)
                rv.elt = @deplate.formatter.format_particle(:format_url, rv, rv.elt, url, nil)
            else
                button = @deplate.variables['hyperHeadingButton'] ||
                    @deplate.parse_and_format_without_wikinames(self, 
                                                                # '{img alt="=>": hyperHeading}', 
                                                                '=>', 
                                                                false)
                rv.elt += @deplate.formatter.format_particle(:format_url, rv, button, url, nil)
            end
        end
        if rv.is_top_heading?
            @deplate.output.simulate_reset
            @deplate.options.heading_names[@top_heading_idx] = rv.elt
            if @deplate.variables['subToC']
                args  = {'sub' => true, 'plain' => true}
                match = []
                toc = Deplate::Command::LIST.new(@deplate, @source, 'toc', match, args, 'LIST')
                toc.level = @level
                toc.level_as_string = level_as_string
                rv = [rv, toc.finish.process].compact.flatten
            end
        end
        rv
    end

    def register_metadata
        stats = @source.stats
        mtime = stats ? stats.mtime : nil
        args  = {
            'type' => 'heading',
            'name' => description,
            'id'   => get_id
        }
        if @abstract
            args['abstract'] = @abstract.to_plain_text
        end
        @registered_metadata << @deplate.get_metadata(@source, args)
        super
    end
    
    def description
        desc = if @args['shortcaption']
                   @args['shortcaption']
               elsif @caption
                   @caption.elt
               else
                   @elt
               end
        printable_particles(desc)
    end

    def register_caption
        @deplate.options.listings.push('toc', self)
        @label << @deplate.elt_label('hd', level_as_string)
    end
end


class Deplate::Element::Break < Deplate::Element
    register_element
    set_formatter :format_break
    set_rx(/^\s*-{2,}8\<-{2,}\s*$/)
end


# An anchor is not a proper element, but is attached to the preceding one
class Deplate::Element::Anchor < Deplate::Element
    register_element
    set_formatter :format_anchor
    set_rx(/^\s*%?#([a-z][a-zA-Z0-9:_-]+)(.*)$/)

    class << self
        def accumulate(src, array, deplate, text, match)
            i = 0
            l = get_text(match)
            Deplate::Core.log(['New anchor', l], :debug)
            r = get_rest(match)
            if r and !r.empty?
                Deplate::Core.log(['Deprecated: Text after anchor', r], :error, src)
            end
            last = array.last
            if last and last.can_be_labelled
                last.put_label([l])
            else
                Deplate::Core.log(["Defer label", l], nil, src)
                deplate.labels_floating << l
            end
        end

        def get_text(match)
            match[1]
        end
        
        def get_rest(match)
            match[2]
        end
        
        def is_volatile?(match, input)
            true
        end
    end
    
    def setup
        put_label([@text])
    end

    def process
        return self
    end
end


# just disappear
class Deplate::Element::Whitespace < Deplate::Element
    register_element
    set_rx(/^\s*$/)
    def_get :text, lambda {@text}

    class << self
        def accumulate(src, array, deplate, text, match)
            Deplate::Core.log(["Whitespace", text], :debug)
            le = array.last
            kw = deplate.options.keep_whitespace
            if le.kind_of?(Deplate::Element::Table) or (kw and !(le and le.collapse))
                e = self.new(deplate, src, text, match, kw)
                if e
                    array << e
                end
            end
        end
    end

    def setup(kw)
        @collapse = true
        @can_be_labelled = false
        @keep_whitespace = kw
    end

    def process
        return @keep_whitespace ? self : nil
    end

    def print
        if @keep_whitespace
            output(@accum.join)
        end
    end
    alias :format_special :print
end


class Deplate::Element::PotentialPageBreak < Deplate::Element
    set_formatter :format_PAGEBREAK
    attr_accessor :enabled
    
    def setup
        @enabled = false
    end
    
    def process
        if @enabled and @deplate.options.multi_file_output
            self
        else
            nil
        end
    end
end


class Deplate::Element::Clip < Deplate::BaseElement
    attr_reader :is_template
    # attr_accessor :prototype

    def initialize(acc, deplate, source)
        super(deplate)
        @acc         = acc
        @elt         = nil
        @source      = source
        @invoker     = nil
        @is_template = false
        @prototype   = nil
    end

    def process
        unless @prototype
            @prototype = @acc.first
            @prototype.args.update(@args) if @prototype
        end
        unless @elt
            @elt = @acc.collect{|p| p.process; p.elt}
            @elt = @deplate.join_particles(@elt)
        end
        return self
    end
   
    def format_clip(invoker, expected)
        unless @elt
            puts caller[0..10].join("\n")
            log("We shouldn't be here. If you can track down when this happens, please send an example to the author.", :anyway)
            process
        end
        if @elt
            if @prototype
                @prototype.match_expected(expected, invoker)
            elsif @elt =~ /\S/
                log(['Internal error', 'prototype=nil', @elt], :error)
            end
        else
            log("Clip is nil, which is quite strange and most likely deplate's error but as I haven't had the time yet to track this down this error still occurs.", :error)
        end
        @elt
    end
    
    def print
        output(@elt)
    end
end


# vim: ff=unix
