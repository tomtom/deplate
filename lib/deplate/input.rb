# encoding: ASCII
# input.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     10-Mär-2005.
# @Last Change: 2010-10-10.
# @Revision:    0.845
#
# = Description
# = Usage
# = TODO
# = CHANGES

require "deplate/common"

# Input: 
class Deplate::Input < Deplate::CommonObject
    class << self
        def hook_post_myname=(name)
            klass = self
            Deplate::Core.class_eval {declare_input_format(klass)}
        end
    end

    class_attribute :myname, 'deplate'

    attr_reader :elements, :commands, :regions, :macros, :skeleton_expander
    attr_reader :paragraph_class, :comment_class, :command_class
    attr_reader :particles, :rx_particles, :particles_ext, :rx_particles_ext

    @@custom_particles = {}
    
    def initialize(deplate, args)
        @deplate  = deplate
        @options  = deplate.options
        @args     = args
        @elements = select_value(args[:elements], Deplate::Element.elements)
        @commands = select_value(args[:commands], Deplate::Command.commands)
        @regions  = select_value(args[:regions ], Deplate::Region.regions)
        @macros   = select_value(args[:macros], Deplate::Macro.macros)
        @paragraph_class = select_value(args[:paragraph_class], Deplate::Element::Paragraph)
        @comment_class   = select_value(args[:comment_class], Deplate::Element::Comment)
        @command_class   = select_value(args[:command_class], Deplate::Element::Command)
        @allow_onthefly_particles = select_value(args[:onthefly_particles], true)
        if @options.skeletons.empty?
            @skeleton_expander = nil
        else
            expander = select_value(args[:expander_class], Deplate::SkeletonExpander)
            @skeleton_expander = expander.new(deplate)
        end
        initialize_particles
    end
   
    def select_value(arg, default)
        case arg
        when :default
            default
        # when Array
        #     p "DBG", arg
        #     # arg.collect {|x| x == :default ? default.dup : x}.flatten
        #     rv = arg.collect {|x| x == :default ? [] : x}.flatten
        #     p "DBG", rv
        #     rv
        else
            arg || default
        end
    end
    private :select_value

    def args_fill_with_default(args)
        # args[:elements]           = nil
        # args[:particles]          = nil
        # args[:particles_ext]      = nil
        # args[:commands]           = nil
        # args[:regions]            = nil
        # args[:macros]             = nil
        # args[:onthefly_particles] = nil
        # args[:paragraph_class]    = nil
        # args[:comment_class]      = nil
        # args[:command_class]      = nil

        args[:elements]           = :default
        args[:particles]          = nil
        args[:particles_ext]      = nil
        args[:commands]           = :default
        args[:regions]            = :default
        args[:macros]             = :default
        args[:onthefly_particles] = :default
        args[:paragraph_class]    = :default
        args[:comment_class]      = :default
        args[:command_class]      = :default

        # args[:elements]           = Deplate::Element.elements
        # args[:particles]          = Deplate::Particle.particles.dup
        # args[:particles_ext]      = Deplate::Particle.particles_ext.dup
        # args[:commands]           = Deplate::Command.commands
        # args[:regions]            = Deplate::Region.regions
        # args[:macros]             = Deplate::Macro.macros
        # args[:onthefly_particles] = true
        # args[:paragraph_class]    = Deplate::Element::Paragraph
        # args[:comment_class]      = Deplate::Element::Comment
        # args[:command_class]      = Deplate::Element::Command
        # args[:expander_class]     = Deplate::SkeletonExpander
    end

    def initialize_particles(alt=false, args=@args)
        always = args[:always]
        if always or @allow_onthefly_particles or !@rx_particles
            # TBD: What was these _custom variables good for?
            @particles_custom ||= select_value(args[:particles], Deplate::Particle.particles)
            if @particles_custom
                # @particles = args[:particles].dup
                @particles = @particles_custom.dup
            else
                @particles = Deplate::Particle.particles.dup
            end
            # @particles = select_value(@particles_custom, Deplate::Particle.particles).dup
            for p in @options.disabled_particles
                disable_particle_class(p)
            end
            initialize_rx(:standard)
        end
        
        if always or !defined?(@particles_ext) or (@allow_onthefly_particles and alt)
            @particles_ext_custom ||= select_value(args[:particles_ext], Deplate::Particle.particles_ext)
            if @particles_ext_custom
                # @particles_ext = args[:particles_ext].dup
                @particles_ext = @particles_ext_custom.dup
            else
                @particles_ext = Deplate::Particle.particles_ext.dup
            end
            # @particles = select_value(@particles_ext_custom, Deplate::Particle.particles_ext).dup
            initialize_rx(:extended)
        else
            @particles_all    = @particles
            @rx_particles_all = @rx_particles
        end
    end

    def initialize_rx(what=:both)
        case what
        when :extended, :both
            if @particles_ext
                @particles_all = @particles + @particles_ext
            else
                @particles_all = @particles
            end
            @rx_particles_all = get_rx_particles(@particles_all)
        else
            @rx_particles = get_rx_particles(@particles)
        end
    end
 
    def register_element(instance, args={})
        # <+TBD+> duplicates will be ignored
        @elements << instance
    end

    def register_macro(instance, args={})
        name = Deplate::CommonGround.get_explicit_id(args)
        if @macros[name]
            @deplate.log(['Macro already defined', name])
        end
        @macros[name] = instance
    end
    
    def register_region(instance, args={})
        name = Deplate::CommonGround.get_explicit_id(args)
        if @regions[name]
            @deplate.log(['Region already defined', name])
        end
        @regions[name] = instance
    end
    
    def register_command(instance, args={})
        name = Deplate::CommonGround.get_explicit_id(args)
        if @commands[name]
            @deplate.log(['Command already defined', name])
        end
        @commands[name] = instance
    end
    
    def register_particle(particle, args={})
        arr = args[:extended] ? @particles_ext : @particles
        id  = args[:id] || particle.name
        rpl = args[:replace]
        oid = rpl ? rpl.name : id
        catch(:cont) do
            old = @@custom_particles[oid]
            if old
                idx = arr.index(old)
                if idx
                    arr[idx] = particle
                    throw :cont
                end
            end
            if rpl and (rpli = arr.index(rpl))
                arr[rpli] = particle
            elsif args[:unshift]
                arr.unshift(particle)
            else
                arr << particle
            end
        end
        @@custom_particles[id] = particle
        initialize_rx(:both)
    end
    
    def remove_named_elements(hash, field, default, elements)
        arr = hash[field] ||= default
        for e in elements
            case e
            when String
                arr.delete(e)
            else
                i = arr.index(e)
                arr.delete(i) if i
            end
        end
    end

    def replace_named_elements(hash, field, default, elements)
        arr = hash[field] ||= default
        arr.collect! do |elt|
            elements.each do |from, to|
                case from
                when String
                    elt.myname == from ? to : elt
                else
                    elt == from ? to : elt
                end
            end
        end
        arr
    end

    def get_rx_particles(particles)
        return Regexp.new(particles.collect do |e|
            e.rx.source[1..-1]
        end.join("|"))
    end

    def get_particles(what, alt=true)
        if alt
            p = @particles_all
            r = @rx_particles_all
        else
            p = @particles
            r = @rx_particles
        end
        case what
        when :rx
            return r
        when :particles
            return p
        else
            return r, p
        end
    end
    
    def disable_particle_class(particle)
        @particles.delete(particle)
    end
       
    # This is the general function for including text from whatever source 
    # that follows the enumeration interface. In general, the more 
    # specialized methods from Deplate::Core should be used to call this.
    def include_string(string, acc_array, linenumber)
        accum  = []
        string = @skeleton_expander.expand(string) if @skeleton_expander
        string.each_line do |line|
            linenumber += 1
            line.chomp!
            unless accum.empty?
                line.gsub!(/^\s+/, '')
            end
            if !unfinished_region?(acc_array.last) and (comment_class.match(line) and !comment_class.show_comment?(@deplate, line))
                next
            else
                use_line_continuation = acc_array.last ? acc_array.last.line_cont : true
                if use_line_continuation and line =~ /(^|[^\\])\\$/
                    accum << line[0..-2]
                else
                    accum << line
                    handle_line(acc_array, accum.join, linenumber)
                    accum = []
                end
            end
        end
        handle_line(acc_array, nil, linenumber)
    end
    
    def handle_line(array, line, lineNumber=-1)
        # p "DBG line=#{line.inspect}"
        last = array.last
        if line
            src = Deplate::Source.new(@deplate.current_source, @deplate.current_source_stats,
                                      lineNumber, nil)
            if (tic = @deplate.variables['embeddedTextRx'])
                # If +embeddedTextRx+ is set, the actual text is hidden in 
                # comments or similar. Other text is printed as 
                # verbatim.
                ec = @deplate.variables['embeddedVerbatim'] || 'Verbatim'
                rx = /^#{tic}/
                if line =~ rx
                    # p "DBG tic", line
                    if $1
                        line = $1
                    else
                        line.sub!(rx, '')
                    end
                    if last and last.kind_of?(Deplate::Element::Region) and last.name == ec and !last.finished?
                        last = finish_last(array, last, lineNumber)
                    end
                else
                    # p "DBG notic", line
                    if !@deplate.switches.last and !ec.empty?
                        if last.kind_of?(Deplate::Element::Region) and last.name == ec
                            last << line
                        elsif line =~ /\S/
                            if last and !last.finished?
                                last = finish_last(array, last, lineNumber)
                            end
                            m = Deplate::Element::Region.pseudo_match(:args => '')
                            Deplate::Element::Region.do_accumulate(src, array, @deplate, '', m, ec)
                            array.last << line if array.last
                        end
                    end
                    return
                end
            end
            if unfinished_region?(last)
                # last is a region
                if line =~ last.endRx
                    last = finish_last(array, last, lineNumber)
                else
                    last << line
                end
            else
                # last is something else
                e, m = match_elements(line)
                if last
                    # so, there is a element in the queue
                    # if e == comment_class
                    #     # and !e.show_comment?(@deplate, line)
                    #     # c = nil
                    # elsif last.finished?
                    if last.finished?
                        # last is finished, so we start a new element
                        c = e || paragraph_class
                    elsif last.to_be_continued?(line, e, m) and (e != comment_class or last.is_a?(comment_class))
                        # this line is something else, so we ask last if it wants 
                        # to be continued
                        case last.multiliner
                        when :match
                            last.push_match(m)
                        when true
                            if @options.keep_whitespace or last.keep_whitespace
                                last << line
                            else
                                last << line.strip
                            end
                        end
                        c = nil
                    elsif e
                        unless e.is_volatile?(m, self)
                            last = finish_last(array, last, lineNumber - 1)
                        end
                        c = e
                    else
                        # last doesn't want this line, so we start a new element
                        last = finish_last(array, last, lineNumber - 1)
                        c = paragraph_class
                    end
                else
                    # as there is no last element, we start a new one in any 
                    # case
                    c = e || paragraph_class
                end
                if c and (c == command_class or !@deplate.switches.last)
                    c.do_accumulate(src, array, @deplate, line, m)
                end
            end
        else
            if last and !last.finished?
                last = finish_last(array, last, lineNumber)
            end
        end
    end
    private :handle_line

    def unfinished_region?(last)
        return last && !last.finished? && last.endRx
    end

    def finish_last(array, last, lineNumber=-1)
        last.source.end  = lineNumber if lineNumber > 0
        # finished_element  = last.finish
        finished_element = array.pop
        finished_element = finished_element.finish
        # finished_element = array.pop.finish
        if finished_element.kind_of?(Array)
            for e in finished_element
                handle_finished_element(array, e)
            end
        else
            handle_finished_element(array, finished_element)
        end
        array.last
    end
    private :finish_last

    def handle_finished_element(array, element)
        filter = @deplate.variables['efilter']
        unless element.nil? or element.drop?(filter)
            pred = array.last
            if pred and pred.unify(element)
                if pred.exclude?(filter)
                    pred.pop(array)
                end
            else
                if !@deplate.labels_floating.empty? and element.can_be_labelled
                    element.put_label(@deplate.labels_floating)
                    @deplate.labels_floating = []
                end
                unless element.exclude?(filter)
                    array << element
                end
            end
        end
    end
    private :handle_finished_element


    ### Elements

    # Test for all elements except Paragraph. It's a real Paragraph if there 
    # is undefined text and the previous element wasn't a "multiliner"
    def match_elements(line)
        @elements.each do |e|
            m = e.match(line)
            if m
                return [e, m]
            end
        end
        m = comment_class.match(line)
        if m
            return [comment_class, m]
        else
            return [nil, @paragraph_class.match(line)]
        end
    end
    private :match_elements


    ### Particles
    
    # This is the method that does the actual parsing of elements into 
    # particles. It takes a regular expression made up of all known particles 
    # and matches the text against it. It splits the text into a prelude, a 
    # match, and the rest. The the prelude is turned into an instance of 
    # Deplate::Particle::Text, the match into a matching particle. The rest is 
    # matched against the grand regular expression again.
    #
    # This approach provides for easy runtime modifications of the 
    # lexer/parser, which wouldn't be possible, I assume, if I had used rexml 
    # or similar ... I assume.
    #
    # Anyway, you should call this method directly unless you have to, but use 
    # the more specialized ones.
    def parse_using(container, text, rx, particles, alt=true, args={})
        rest = text
        rt   = []
        last = ''
        src  = container ? container.source : nil
        while !rest.empty?
            begin
                mx = rx.match(rest)
            rescue RegexpError => e
                if rest.size > 60
                    sample = "%s ..." % rest[0..60]
                else
                    sample = rest
                end
                log_error(container, ['Regexp error when parsing', sample], :error, src)
            rescue Exception => e
                puts e.backtrace[0..10].join("\n")
                raise e
            end
            if mx
                rest = mx.post_match
                catch(:ok) do
                    particles.each do |e|
                        m = e.match(mx[0])
                        if m
                            pc = e.pre_condition
                            unless pc && !pc.call(mx)
                                pre = mx.pre_match
                                unless pre.empty?
                                    rt << as_text(container, rt, mx.pre_match, alt, last, args)
                                end
                                txt = last + mx.pre_match
                                begin
                                    rt << e.new(@deplate, container, rt, m, alt, txt, rest)
                                rescue Exception => exc
                                    puts exc
                                    # puts exc.backtrace[0..10].join("\n")
                                    # puts "#{exc}\nInternal error when initializing %s: %s" % [e.name, txt]
                                    # raise exc
                                end
                                throw :ok
                            end
                        end
                    end
                    txt = mx.pre_match + mx[0]
                    rt << as_text(container, rt, txt, alt, last, rest, args)
                end
                last = mx[0]
            else
                rt << as_text(container, rt, rest, alt, last, "", args)
                break
            end
        end
        if (filter = @deplate.variables['pfilter'])
            # c = container.kind_of?(Deplate::BaseParticle) ? container : nil
            rt.delete_if do |p|
                p.exclude?(filter, args[:pcontainer])
            end
        end
        return rt
    end

    def as_text(container, context, match, alt, last="", rest="", args={})
        case match
        when String
            match = Deplate::Particle::Text.pseudo_match(match)
        end
        Deplate::Particle::Text.new(@deplate, container, context, match, alt, last, rest, args)
    end
    
    def parse_with_particles(container, text, particles, alt=true)
        parse_using(container, text, get_particles(:rx, alt), particles, alt)
    end

    def parse_with_source(source, text, alt=true, excluded=nil)
        container = Deplate::PseudoContainer.new(@deplate, :source => source)
        parse(container, text, alt, :excluded => excluded)
    end

    def parse(container, text, alt=true, args={})
        excluded = args[:excluded] || []
        rx, particles = get_particles(:both, alt)
        for p in excluded
            case p
            when Proc
                particles.delete_if(&p)
            else
                particles.delete(p)
            end
        end
        parse_using(container, text, rx, particles, alt, args)
    end

    ### Arguments
    # @@rxsrc_args = %{(\\w+?)(!|=("(\\\\"|[^"])*"|(\\\\=|.)+?))(\\s*$|(?= \w+(!|=)))}
    # @@rxsrc_args = %{(\\w+?)(!|=((\\\\=|.)+?))(\\s*$|(?= \w+(!|=)))}
    # @@rxsrc_argval       = %{("(\\\\"|[^"])*?"|(\\\\=|\\\\:|\\\\!|[^=!]+)+?)}
    # @@rxsrc_argval       = %{(\\\\=|\\\\:|[^=:]*)+?}
    # @@rxsrc_argval = %{("(\\\\"|[^"])*?"|(\\\\ |\\\\=|\\\\:|\\\\!|[%s]+)+?)}
    # @@rxsrc_argval = %{("(\\\\"|[^"])*"|\\\\.|[%s"]+)+?}
    # @@rxsrc_argval = %{("(\\\\"|[^"])*"|\\([^)]+\\)|\\\\.|[^%s"]+)+?}
    @@rxsrc_argval = %{("(\\\\"|[^"])*"|\\([^)]+\\)|\\\\.|[^%s"]+)*?}

    # @@rxsrc_key    = %{[$@\\w]+(\\[\\S*?\\])?}
    # @@rxsrc_args1  = %{(#{@@rxsrc_key})(!|=(#{@@rxsrc_argval}))\\s*} % "=!:"
    # @@rxsrc_args2  = %{(#{@@rxsrc_key})(!|=(#{@@rxsrc_argval}))\\s*} % "=!"
    # @@rx_args      = /^\s*(#{@@rxsrc_args2})(?=(\s*$|\s+#{@@rxsrc_key}(!|=)))/
    # @@rx_argstext  = /^\s*((#{@@rxsrc_args1})*?)(:\s*(.+))?$/
    # @@ri_text = 9

    @@rxsrc_key    = %{[$@\\w]+(\\[[^\\]]*\\])?[&+]?}
    # @@rxsrc_args1  = %{(#{@@rxsrc_key})(!|=(#{@@rxsrc_argval}))\\s*} % "=!:"
    # @@rxsrc_args2  = %{(#{@@rxsrc_key})(!|=(#{@@rxsrc_argval}))\\s*} % "=!"
    @@rxsrc_args1  = %{(#{@@rxsrc_key})((?>!)|(?>=)(#{@@rxsrc_argval}))\\s*} % "=!:"
    @@rxsrc_args2  = %{(#{@@rxsrc_key})((?>!)|(?>=)(#{@@rxsrc_argval}))\\s*} % "=!"
    @@rx_args      = /^\s*(#{@@rxsrc_args2})(?=(\s*$|\s+#{@@rxsrc_key}(!|=)))/
    @@rx_argstext  = /^\s*((#{@@rxsrc_args1})*?)(:\s*(.+))?$/
    @@ri_text = 9

    # @@rxsrc_key    = %{\\s+([$@[:alnum:]_]+(\\[[^\\]]*\\])?)}
    # # @@rxsrc_key    = %{\\s+([$@[:alnum:]_]+(\\[[^\\]]*\\])?)}
    # @@rxsrc_args1  = %{#{@@rxsrc_key}(!|=(#{@@rxsrc_argval}))} % "=!:"
    # @@rxsrc_args2  = %{#{@@rxsrc_key}(!|=(#{@@rxsrc_argval}))} % "=!"
    # @@rx_args      = /^(#{@@rxsrc_args2})(?=(\s*$|#{@@rxsrc_key}(!|=)))/
    # @@rx_argstext  = /^((#{@@rxsrc_args1})*?)\s*(:\s*(.+))?$/
    # @@ri_text = 9

    def parse_args(argText, container=nil, firstPass=true, parseText=false)
        unless argText
            return nil
        end
        argText.strip!
        if argText.empty?
            return [{}, '']
        else
            # argText.insert(0, ' ')
        end
        # p "DBG 0 #{argText.inspect}"
        if firstPass
            m = @@rx_argstext.match(argText)
            m &&= m.captures
        else
            m = [argText]
        end
        accum = {}
        if m
            args = m[0]
            # args.insert(0, ' ')
            text = m[@@ri_text]
            # p "DBG 1.1 m=#{m.inspect}"
            # p "DBG 1.2 args=#{args.inspect} => #{(args =~ /\S/).inspect}"
            # p "DBG 1.3 text=#{text.inspect}"
            while args =~ /\S/
                if args =~ /^[^=[:space:]]+=[^"([:space:]]*?[^\\"(]([!=])/
                    log_error(container, ['Argument parse error', $1, args])
                    return [{}, '']
                end
                # p "DBG 2.1 #@@rx_args"
                # p "DBG 2.2 #{args.inspect}"
                m = @@rx_args.match(args)
                # p "DBG 3"
                if m
                    key = m[2]
                    val = m[5]
                    # p "DBG #{key.inspect}=#{val.inspect}"
                    Deplate::Core.canonic_args(accum, key, val, container && container.source)
                    args = m.post_match
                    if args.empty?
                        break
                    end
                else
                    log_error(container, ['Argument parse error', args, argText])
                    break
                end
            end
            if parseText
                if text
                    parsed = parse(container, text)
                else
                    parsed = []
                end
            end
        else
            text   = nil
            parsed = nil
        end
        id = accum['id']
        if id
            accum['@id'] = id
            accum['id']  = @deplate.formatter.encode_id(id)
        end
        fmt = accum['fmt']
        accum.delete('fmt') if fmt
        ifOpt0 = ifOpt = accum['if']
        if ifOpt
            accum.delete('if')
            ifOpt = Deplate::Element::Command.check_switch(@deplate, ifOpt)
        else
            ifOpt = true
        end
        if ifOpt0 and !ifOpt and accum['else']
            text = accum['else']
            accum.delete('else')
            parsed = parse(container, text)
            ifOpt = true
        end
        nofmt = accum['nofmt']
        accum.delete('nofmt') if nofmt
        nofmt ||= accum['noFmt']
        accum.delete('noFmt') if nofmt
        if (!firstPass or
            (ifOpt and
             (!fmt || @deplate.formatter.matches?(fmt)) and 
             (!nofmt || !(@deplate.formatter.matches?(nofmt)))))
            if parseText
                return [accum, text, parsed]
            else
                return [accum, text || '']
            end
        else
            raise Deplate::DontFormatException
        end
    end

    def allow_set_variable(var)
        true
    end
    
    private
    def log_error(container, text)
        (container || @deplate).log(text, :error)
    end
end

# class Deplate::Core
#     declare_input_format(Deplate::Input)
# end

