# encoding: ASCII
# commands.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     08-Mai-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.1316

module Deplate::Names
    module_function
    def name_match_c(text)
        if text =~ /^\{(.*)\}$/
            return {:surname => $1}
        end
    end

    def name_match_sf(text)
        m = /^\s*(.+?),\s*(.+?)\s*$/.match(text)
        return m ? {:firstname => m[2], :surname => m[1]} : nil
    end
    
    def name_match_fs(text)
        m = /^\s*(\S+(\s+\S+)*?)\s+(\S+)\s*$/.match(text)
        return m ? {:firstname => m[1], :surname => m[3]} : nil
    end
end

class Deplate::Command < Deplate::Element
    include Deplate::Names

    @@commands = {}
    
    class << self
        # attr_reader :commands
        def commands
            @@commands
        end

        def register_as(name, c=self)
            @@commands[name] = self
        end

        def update_variables(hash, opts, args)
            if args
                opts ||= {}
                d = args['date']
                args['date'] = get_date(d, args) if d
                if opts['add']
                    if opts['add'].kind_of?(String)
                        sep = opts['add']
                    else
                        sep = ' '
                    end
                    args.each_pair do |k,v|
                        if hash[k]
                            v = hash[k] + sep + v
                        end
                        hash[k] = v
                    end
                else
                    hash.update(args)
                end
            else
                Deplate::Core.log(['No arguments', opts], :error, src)
            end
        end
    end
    
    def setup(args, cmd)
        # @collapse   = false
        @name       = cmd
        @accum      = [@text]
        @can_be_labelled = false
        @args.update(args)
        setup_command
        update_args
    end
    
    def setup_command
    end

    def finish
        @elt = [ @accum.join(' ') ]
        return self
    end

    def process
        process_etc
        @elt = @elt.join("\n")
        return self
    end

    def format_special
        @deplate.formatter.format_unknown(self)
    end
end


class Deplate::Command::CAP < Deplate::Command
    register_as 'CAP'
    register_as 'CAPTION'

    class << self
        def accumulate(src, array, deplate, text, match, args, cmd)
            Deplate::Core.log("%s: %s" % [cmd, text], :debug, src)
            last = array.last
            if last
                last.set_caption(Deplate::CaptionDef.new(text, args, src), false, args['extended'] || args['bang'])
            else
                Deplate::Core.log(["Cannot attach caption to", nil], :error, src)
            end
        end
    end
end


class Deplate::Command::LANG < Deplate::Command
    register_as 'LANG'
    register_as 'LANGUAGE'
    self.volatile = true
    
    def self.accumulate(src, array, deplate, text, match, args, cmd)
        Deplate::Core.log("%s: %s" % [cmd, text], :debug, src)
        deplate.set_lang(text)
    end
end


class Deplate::Command::INC < Deplate::Command
    register_as 'INC'
    register_as 'INCLUDE'
   
    class << self
        def accumulate(src, array, deplate, text, match, args, cmd)
            Deplate::Core.log("%s: %s" % [cmd, text], :debug, src)
            var  = args['var'] || args['var'] || args['val']
            if args.has_key?('file')
                if text
                    Deplate::Core.log(['Conflicting arguments', 'file > @anonymous'], :error, src)
                end
                text = args['file']
            end
            args['INCLUDED'] = src.file
            vars         = swap_variables(deplate, args)
            input_format = args['inputFormat']
            pif          = deplate.push_input_format(input_format)

            begin
                if var
                    strings = deplate.variables[var]
                    if strings
                        deplate.include_stringarray(strings, array, nil, src.file)
                    else
                        Deplate::Core.log(['Unknown doc variable', var], :error, src)
                    end
                elsif !text or text == ''
                    Deplate::Core.log(['Malformed command', cmd, text], :error, src)
                else
                    fn = deplate.find_in_lib(text, :pwd => true)
                    if fn
                        deplate.include_file(array, fn, args)
                    else
                        Deplate::Core.log(['File not found', text], :error, src)
                    end
                end
            ensure
                restore_variables(deplate, vars)
                deplate.pop_input_format(input_format) if pif
            end
        end

        def swap_variables(deplate, args, vars={})
            # vars[:deplate] ||= deplate.variables.dup
            args.each do |var, val|
                case var
                when 'syntax'
                    var = 'codeSyntax'
                when 'codeSyntax', 'embeddedTextRx', 'embeddedVerbatim'
                else
                    if var[0..0] == '$'
                        var = var[1..-1]
                    else
                        next
                    end
                end
                has_key = deplate.variables.has_key?(var)
                vars[var] = {
                    :has_key => has_key,
                    :value => has_key ? deplate.variables[var] : nil,
                }
                deplate.variables[var] = val
            end
            vars
        end

        def restore_variables(deplate, hash)
            # deplate.variables = hash[:deplate]
            hash.each do |var, val|
                if val[:has_key]
                    deplate.variables[var] = val[:value]
                else
                    deplate.variables.delete(var)
                end
            end
        end
    end
end


class Deplate::Command::VAR < Deplate::Command
    register_as 'DOC'
    register_as 'VAR'
    self.volatile = true

    class << self
        def set_variable(deplate, var, value, args={}, src=nil)
            if deplate.input.allow_set_variable(var)
                deplate.register_metadata(src, 
                                          'type'  => 'variable', 
                                          'name'  => var,
                                          'value' => value
                                         )
                update_variables(deplate.variables, args, var => value)
                return true
            else
                Deplate::Core.log(['Disabled', var], :error, src)
                return false
            end
        end
        
        def accumulate(src, array, deplate, text, match, args, cmd)
            Deplate::Core.log("%s: %s" % [cmd, text], :debug, src)
            id = args['id']
            if id
                if deplate.input.allow_set_variable(id)
                    set_variable(deplate, id, text, args, src)
                end
            else
                cnt = Deplate::PseudoContainer.new(deplate, args)
                cnt.source = src
                opts, text = deplate.input.parse_args(text, cnt, false)
                for k, v in opts
                    unless set_variable(deplate, k, v, args, src)
                        opts.delete(k)
                    end
                end
            end
        end
    end
end


class Deplate::Command::PUSH < Deplate::Command::VAR
    register_as 'PUSH'
    self.volatile = true
    def self.accumulate(src, array, deplate, text, match, args, cmd)
        args['add'] ||= ','
        super
    end
end


class Deplate::Command::KEYWORDS < Deplate::Command::VAR
    register_as 'KEYWORDS'
    self.volatile = true
    def self.accumulate(src, array, deplate, text, match, args, cmd)
        args['id'] = 'keywords'
        super
    end
end


class Deplate::Command::OPT < Deplate::Command
    register_as 'OPT'
    # register_as 'ATTR'
    register_as 'PROP'
    register_as 'PP'
    self.volatile = true
    def self.accumulate(src, array, deplate, text, match, args, cmd)
        Deplate::Core.log("%s: %s" % [cmd, text], :debug, src)
        elt = array.last
        if elt
            cnt = Deplate::PseudoContainer.new(deplate, args)
            cnt.source = src
            opts, text = deplate.input.parse_args(text, cnt, false)
            deplate.register_id(opts, elt)
            update_variables(elt.args, args, opts)
            elt.update_args
        else
            Deplate::Core.log(['No element given', match[0]], :error, src)
        end
    end
end


class Deplate::Command::PUT < Deplate::Command
    register_as 'PUT'
    register_as 'CLIP'
    register_as 'SET'
    def self.accumulate(src, array, deplate, text, match, args, cmd)
        Deplate::Core.log("%s: %s" % [cmd, text], :debug, src)
        id = args['id']
        if id
            text = deplate.parse_with_source(src, text, false)
            deplate.set_clip(id, Deplate::Element::Clip.new(text, deplate, src))
        else
            Deplate::Core.log(['No ID given', text], :error, src)
        end
    end
end


class Deplate::Command::GET < Deplate::Command
    register_as 'GET'
    set_formatter :format_GET
    
    def setup_command
        @id = @args['id'] || @accum[0]
    end
    
    def process
        @elt = @deplate.get_clip(@id)
        if @elt
            return self
        else
            log(['GET: Clip not found', @id], :error)
            return nil
        end
    end
end


class Deplate::Command::XARG < Deplate::Command
    register_as 'XARG'
    register_as 'XVAL'
    # self.volatile = true
    
    def setup_command
        id = args['id'] || @accum[0]
        @elt = @deplate.variables[id] || @args['default']
        if @elt
            @elt = Deplate::Command::ARG.preformat_element(@elt, @args)
        else
            log(['Unknown variable', id, @name], :error)
        end
    end

    def format_special
        @elt
    end
end


class Deplate::Command::ARG < Deplate::Command
    register_as 'ARG'
    register_as 'VAL'
    # self.volatile = true

    class << self
        def accumulate(src, array, deplate, text, match, args, cmd)
            Deplate::Core.log("%s: %s" % [cmd, text], :debug, src)
            id = args['id'] || text
            val = deplate.variables[id] || args['default']
            if val
                acc = preformat_element(val, args)
                d = deplate.options.master ? deplate.options.master : deplate
                d.include_stringarray(acc, array, src.begin, src.file)
            else
                Deplate::Core.log(['Unknown variable', id, cmd], :error, src)
            end
        end

        def preformat_element(elt, args)
            case elt
            when Array
                elt = elt.collect {|text| preformat_text(text, args)}
            else
                elt = preformat_text(elt, args)
            end
            elt.flatten!
            return elt
        end

        def preformat_text(text, args)
            text = Deplate::Core.escape_characters(text, args)
            text = Deplate::CommonGround.post_process_text(text, args)
            return text.split(/[\n\r]/).each {|l| l.chomp!}
        end
    end
end


class Deplate::Command::BIB < Deplate::Command
    register_as 'BIB'
    self.volatile = true
    class << self
        def accumulate(src, array, deplate, text, match, args, cmd)
            Deplate::Core.log("%s: %s" % [cmd, text], :debug, src)
            bibs = text.strip.split(/\s*\|\s*/)
            deplate.options.bib += bibs
            deplate.formatter.read_bib(bibs)
        end
    end
end


class Deplate::Command::TITLE < Deplate::Command
    register_as 'TITLE'
    register_as 'TI'
    self.volatile = true
    def self.accumulate(src, array, deplate, text, match, args, cmd)
        Deplate::Core.log('%s: %s' % [cmd, text], :debug, src)
        c = deplate.parse_with_source(src, text, false)
        deplate.set_clip('title', Deplate::Element::Clip.new(c, deplate, src))
        deplate.register_metadata(src, 
                                  'type' => 'metadata', 
                                  'name' => 'title',
                                  'value' => text
                                 )
    end
end


class Deplate::Command::AUTHOR < Deplate::Command
    register_as 'AUTHOR'
    register_as 'AU'
    self.volatile = true
    class << self
        def accumulate(src, array, deplate, text, match, args, cmd)
            Deplate::Core.log('%s: %s' % [cmd, text], :debug, src)
            deplate.options.author ||= []
            for this in text.split(/([;\/]|\s+(&|and))\s+/)
                unless this =~ /^\s*([;\/&]|and)\s*$/
                    author = Deplate::Names.name_match_sf(this) || 
                        Deplate::Names.name_match_fs(this) || {}
                    sn = args['surname']
                    author[:surname] = sn if sn
                    fn = args['firstname']
                    author[:firstname] = fn if fn
                    if this.empty?
                        author[:name] = args['name'] || '%s %s' % [args['firstname'], args['surname']]
                    else
                        author[:name] = this
                    end
                    author[:note] = args['note']
                    deplate.options.author << author
                end
            end
            sep     = deplate.variables['authorSep'] || '; '
            authors = deplate.options.author.collect {|h| h[:name]}
            authors = authors.join(sep)
            parsed  = deplate.parse_with_source(src, authors, false)
            deplate.set_clip('author', Deplate::Element::Clip.new(parsed, deplate, src))
            deplate.register_metadata(src, 
                                      'type' => 'metadata', 
                                      'name' => 'author',
                                      'value' => authors
                                     )
        end
    end
end


class Deplate::Command::AUTHORNOTE < Deplate::Command
    register_as 'AUTHORNOTE'
    register_as 'AN'
    self.volatile = true
    def self.accumulate(src, array, deplate, text, match, args, cmd)
        Deplate::Core.log('%s: %s' % [cmd, text], :debug, src)
        unless text.empty?
            author = deplate.options.author.last
            if author
                author[:note] = text
            end
        end
        ans = deplate.options.author.collect {|h| h[:note]}
        sep = deplate.variables['authorSep'] || '; '
        ans = ans.compact.join(sep)
        parsed = deplate.parse_with_source(src, ans, false)
        deplate.set_clip('authornote', Deplate::Element::Clip.new(parsed, deplate, src))
        deplate.register_metadata(src, 
                                  'type' => 'metadata', 
                                  'name' => 'authornote',
                                  'value' => ans
                                 )
    end
end


class Deplate::Command::DATE < Deplate::Command
    register_as 'DATE'
    self.volatile = true
    def self.accumulate(src, array, deplate, text, match, args, cmd)
        Deplate::Core.log('%s: %s' % [cmd, text], :debug, src)
        d = get_date(text, args)
        c = deplate.parse_with_source(src, d, false)
        deplate.set_clip(cmd.downcase, Deplate::Element::Clip.new(c, deplate, src))
        deplate.register_metadata(src, 
                                  'type' => 'metadata', 
                                  'name' => 'date',
                                  'value' => d
                                 )
    end
end


class Deplate::Command::IMG < Deplate::Command
    register_as 'IMG'
    register_as 'IMAGE'
    register_as 'FIG'
    register_as 'FIGURE'
    set_formatter :format_IMG

    def register_caption
        register_figure
    end
end


class Deplate::Command::MAKETITLE < Deplate::Command
    register_as 'MAKETITLE'
    set_formatter :format_title
    def setup_command
        if @args['page']
            @deplate.variables['classOptions'] = Deplate::Core.push_value(@deplate.variables['classOptions'], 'titlepage')
        end
    end
end


class Deplate::Command::MAKEBIB < Deplate::Command
    register_as 'MAKEBIB'
    set_formatter :format_MAKEBIB
    def setup_command
        unless @text.nil? or @text.empty? or @deplate.variables['bibStyle']
            log(['Setting variable', 'bibStyle', @text], :anyway)
            @deplate.variables['bibStyle'] = @text
        end
    end
end


class Deplate::Command::LIST < Deplate::Command
    register_as 'LIST'
    set_formatter :format_LIST
end

class Deplate::Command::DEFLIST < Deplate::Command
    register_as 'DEFLIST'
    self.volatile = true
    def self.accumulate(src, array, deplate, text, match, args, cmd)
        Deplate::Core.log("%s: %s" % [cmd, text], :debug, src)
        list = args['id'] || args['list'] || text
        deplate.options.listings.def_listing(list, nil, args)
        i = deplate.current_heading
        p = args['parent']
        deplate.options.counters.def_counter(list, :parent => p)
    end
end

class Deplate::Command::REGISTER < Deplate::Command
    register_as 'REGISTER'
    self.volatile = true
    def self.accumulate(src, array, deplate, text, match, args, cmd)
        Deplate::Core.log("%s: %s" % [cmd, text], :debug, src)
        list = args['id'] || args['list']
        if list
            elt = array.last
            if elt
                name = args['name'] || text
                if name and !name.empty?
                    cap = Deplate::CaptionDef.new(name, args, src)
                    elt.set_caption(cap)
                end
                elt.register_in_listing(list, args)
                return
            end
        end
        Deplate::Core.log(['Nothing to register', list], :error, src)
    end
end


class Deplate::Command::DEFCOUNTER < Deplate::Command
    register_as 'DEFCOUNTER'
    self.volatile = true
    def self.accumulate(src, array, deplate, text, match, args, cmd)
        Deplate::Core.log("%s: %s" % [cmd, text], :debug, src)
        c = args['id'] || args['counter'] || text
        # i = deplate.current_heading
        p = args['parent']
        deplate.options.counters.def_counter(c, :parent => p)
    end
end

class Deplate::Command::COUNTER < Deplate::Command
    register_as 'COUNTER'
    self.volatile = true
    def self.accumulate(src, array, deplate, text, match, args, cmd)
        Deplate::Core.log("%s: %s" % [cmd, text], :debug, src)
        c = args['id'] || args['counter'] || text
        if args['reset']
            # <+TBD+>
        elsif (by = args['increase'])
            by = by.to_i
            l  = args['level']
            # <+TBD+>
        else
            Deplate::Core.log(['#COUNTER', 'Missing directive'], :error, src)
        end
    end
end


class Deplate::Command::TABLE < Deplate::Command
    register_as 'TABLE'
    def setup_command
        if File.exist?(@text)
            File.open(@text) {|io| @accum = io.read.split(/[\r\n]+/)}
        else
            log(['File not found', @text], :error)
        end
    end
    
    def finish
        rv = Deplate::Regions::Table.make_char_separated(self, @accum, @args['sep'])
        rv.unify_props(self)
        rv
    end
end


class Deplate::Command::IDX < Deplate::Command
    register_as 'IDX'
    self.volatile = true
    set_formatter :format_IDX
    
    class << self
        def accumulate(src, array, deplate, text, match, args, cmd)
            i = -1
            while array[i] and array[i].kind_of?(Deplate::Element::Whitespace)
                i -= 1
            end
            e = array[i]
            if e
                out = get_indices(e, deplate, args, text, src)
                pseudocontainer = Deplate::PseudoContainer.new(deplate, :args => args)
                e.postponed_preformat << Proc.new do |container|
                    out.collect! do |idx|
                        deplate.formatter.format_particle(:format_index, pseudocontainer, idx)
                    end
                end
                e.postponed_format << Proc.new do |container|
                    out.delete('')
                    out.compact!
                    container.output(out.join) unless out.empty?
                end
            else
                array << self.new(deplate, src, text, match, args, cmd)
            end
        end

        def get_indices(container, deplate, args, text, source)
            accum = []
            auto  = args['auto']
            auto  = deplate.variables['autoindex'] if auto.nil?
            for i in Deplate::Core.split_list(text, ';', nil, source)
                # <+TBD IDX+>idx = deplate.add_index(nil, i, deplate.get_current_heading)
                idx = deplate.add_index(container, i)
                Deplate::Particle.auto_indexing(deplate, idx) if auto
                accum << idx
                container.add_metadata(source,
                                       'type'  => 'index', 
                                       'name'  => idx.name,
                                       'label' => idx.label
                                      )
            end
            return accum
        end
    end
    
    def setup_command
        @accum = Deplate::Command::IDX.get_indices(self, @deplate, @args, @text, @source)
    end

    def finish
        return self
    end
    
    def process
        @accum.collect! do |idx|
            deplate.formatter.format_particle(:format_index, self, idx)
        end
        @accum.delete("")
        @accum.compact!
        @elt = [ @accum.join ]
        super
    end
end


class Deplate::Command::AUTOIDX < Deplate::Command
    register_as 'AUTOIDX'
    self.volatile = true
    def self.accumulate(src, array, deplate, text, match, args, cmd)
        Deplate::Core.log("%s: %s" % [cmd, text], :debug, src)
        hd  = deplate.get_current_heading
        for i in Deplate::Core.split_list(text, ';', nil, src)
            Deplate::Particle.auto_indexing(deplate, deplate.add_index(nil, i, hd))
        end
    end
end


class Deplate::Command::NOIDX < Deplate::Command
    register_as 'NOIDX'
    self.volatile = true
    def self.accumulate(src, array, deplate, text, match, args, cmd)
        Deplate::Core.log("%s: %s" % [cmd, text], :debug, src)
        for i in Deplate::Core.split_list(text, ';', nil, src)
            deplate.remove_index(self, i)
        end
    end
end


class Deplate::Command::DONTIDX < Deplate::Command
    register_as 'DONTIDX'
    self.volatile = true
    def self.accumulate(src, array, deplate, text, match, args, cmd)
        Deplate::Core.log("%s: %s" % [cmd, text], :debug, src)
        deplate.options.dont_index += Deplate::Core.split_list(text, ';', nil, src)
    end
end


class Deplate::Command::WITH < Deplate::Command
    register_as 'WITH'
    def self.accumulate(src, array, deplate, text, match, args, cmd)
        Deplate::Core.log("%s: %s" % [cmd, text], :debug, src)
        file = args["file"]
        body = nil
        if file
            File.open(file) {|io| body = io.readlines}
        else
            arg = args["arg"] || args["var"]
            if arg
                body = deplate.variables[arg]
                case body
                when String
                    body = body.split(/[\n\r]/)
                end
            end
        end
        if body
            body.each {|l| l.chomp!}
            sep = "-=deplate=-%.10f-=end=-" % Time.new.to_f
            acc = ["#%s <<%s" % [text, sep], *body] << sep
            deplate.include_stringarray(acc, array, src.begin, src.file)
        else
            Deplate::Core.log(["No input! Skip", text], :error, src)
        end
    end
end


class Deplate::Command::ABBREV < Deplate::Command
    register_as 'ABBREV'
    self.volatile = true
    @@abbrevn = 0
   
    class << self
        def accumulate(src, array, deplate, text, match, args, cmd)
            Deplate::Core.log("%s: %s" % [cmd, text], :debug, src)
            rx  = nil
            rs  = nil
            tx  = nil
            cmd = nil
            catch(:exit) do
                w = args['word'] || args['w'] || args['wd']
                if w
                    # rs = %{\\b%s\\b} % Regexp.escape(w)
                    # rs = %{\\b%s(?=[^#{Deplate::HyperLink.chars}])} % Regexp.escape(w)
                    rs = %{\\b%s(?=([[:punct:][:cntrl:][:space:]]|$))} % Regexp.escape(w)
                    # tx = "#{Deplate::Core.remove_backslashes(text.inspect)}"
                    # tx = "#{text.inspect}"
                    # tx = text.inspect
                    tx = text
                    throw :exit
                end
                s = args['symbol'] || args['sym']
                if s
                    rs = %{`%s} % Regexp.escape(s)
                    # tx = "#{Deplate::Core.remove_backslashes(text.inspect)}"
                    # tx = text.inspect
                    tx = text
                    throw :exit
                end
                r = args['regexp'] || args['rx']
                if r
                    rs = r
                    tx = lambda {|p| p.match[0].gsub(Regexp.new(r), text)}
                    throw :exit
                end
            end
            if rs
                if args['plain']
                    # cmd = %{@deplate.formatter.plain_text(#{tx})}
                    cmd = lambda {|c, t| c.deplate.formatter.plain_text(t)}
                    specific = false
                elsif args['native'] or args['ins']
                    cmd = lambda {|c, t| t}
                    specific = true
                else
                    # cmd = %{@deplate.parse_and_format(@container, #{tx}, false)}
                    cmd = lambda {|c, t| c.deplate.parse_and_format(c, t, false)}
                    specific = false
                end
                deplate.options.abbrevs[[rs, deplate.formatter.formatter_name]] = [tx, cmd]
                rx = Regexp.new("^#{rs}")
                # body = <<-EOR
                #     set_rx(#{rx.inspect})
                #     def setup
                #         @elt = #{cmd}
                #     end
                # EOR
                body = <<-EOR
                    set_rx(#{rx.inspect})
                    def setup
                        tx, cmd = @deplate.options.abbrevs[[#{rs.inspect}, @deplate.formatter.formatter_name]]
                        case cmd
                        when Proc
                            tx   = tx.call(self) if tx.kind_of?(Proc)
                            @elt = cmd.call(@container, tx)
                        when String
                            @elt = cmd
                        else
                            log(['Internal error', 'ABBREV', #{rs.inspect}, cmd.class], :error)
                        end
                    end
                EOR
                cls = Deplate::Cache.particle(deplate, body, 
                                              :register => true,
                                              :specific => specific,
                                              :unshift => args['priority']
                                             )
            else
                Deplate::Core.log(["No pattern specified", args], :error, src)
            end
        end
    end
end


class Deplate::Command::MODULE < Deplate::Command
    register_as 'MODULE'
    register_as 'MOD'
    class << self
        def accumulate(src, array, deplate, text, match, args, cmd)
            Deplate::Core.log("%s: %s" % [cmd, text], :debug, src)
            deplate.require_module(text)
            deplate.call_methods_matching(deplate, /^hook_late_require_/)
            # deplate.initialize_particles(false, :always => true)
        end
    end
end


class Deplate::Command::LTX < Deplate::Command
    register_as 'LTX'
    register_as 'INLATEX'
    class << self
        def accumulate(src, array, deplate, text, match, args, cmd)
            Deplate::Core.log("%s: %s" % [cmd, text], :debug, src)
            m = []
            m[Deplate::Element::Region.rxi_name]   = 'Ltx'
            m[Deplate::Element::Region.rxi_args]   = match[2] 
            m[Deplate::Element::Region.rxi_endrx]  = Regexp.escape('_$%{}%$_')
            m[Deplate::Element::Region.rxi_indent] = ''
            text += "\n_$%{}%$_"
            Deplate::Element::Region.accumulate(src, array, deplate, text, m)
        end
    end
end

class Deplate::Element::PAGE < Deplate::Command
    register_as 'PAGE'
    class << self
        def accumulate(src, array, deplate, text, match, args, cmd)
            Deplate::Core.log("%s: %s" % [cmd, text], :debug, src)
            m = []
            Deplate::Element::Break.accumulate(src, array, deplate, text, m)
        end
    end
end

class Deplate::Command::NOP < Deplate::Command
    register_as 'NOP'

    def setup_command
        @embedable = false
    end

    def finish
        return self
    end
    
    def process
    end
end

