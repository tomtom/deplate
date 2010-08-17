# encoding: ASCII
# formatter.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     31-Okt-2004.
# @Last Change: 2010-08-17.
# @Revision:    0.2070

require 'deplate/abstract-class'
require 'deplate/common'
require 'deplate/encoding'
require 'strscan'

# Description:
# An abstract formatter class
# 
# Usage:
# 
# TODO:
# 
# CHANGES:
# 

class Deplate::Formatter < Deplate::CommonObject
    class_attribute :formatter

    class_attribute :suffix
    class_attribute :myname
    class_attribute :related, []
    class_attribute :rx
    class_attribute :label_mode, :enclose
    class_attribute :label_delegate, []
    class_attribute :label_once, []
    
    class_attribute :naked_agents, [
        :format_label,
        :format_index,
    ]

    class_attribute :blacklist_latex, [
        'include',  'def',  'command', 'loop', 'repeat', 
        'open', 'toks', 'output', 'input', 'catcode', 'name', '^^', 
        '\\every', '\\errhelp', '\\errorstopmode', '\\scrollmode', 
        '\\nonstopmode', '\\batchmode', '\\read', '\\write', 'csname', 
        '\\newhelp', '\\uppercase',  '\\lowercase', '\\relax', 
        '\\aftergroup', '\\afterassignment', '\\expandafter', 
        '\\noexpand', '\\special', '\\usepackage'
    ]

    class << self
        def noop(context, name)
            context.module_eval %{
                def #{name}(*args)
                    return ""
                end
            }
        end

        def hook_post_myname=(name)
            klass = self
            Deplate::Core.class_eval {declare_formatter(klass)}
        end

        # <+TBD+>Shouldn't services belong to the formatter?
        def def_service(name, &block)
            # prefix = @formatter.class.myname.gsub('\W', '__')
            # method = ['svc', prefix, name].join('_')
            method = ['svc', name].join('_')
            self.class_eval do
                define_method(method, &block)
            end
            init  = ['formatter_initialize', method].join('_')
            sname = name.gsub(/_(.)/) {$1.capitalize}
            self.class_eval do
                define_method(init) do
                    @doc_services[name]  = method
                    @doc_services[sname] = method
                end
            end
        end

        def set_options_for_file(options, file=nil)
            case file
            when '-'
                options.ext      = ''
                options.srcdir ||= Dir.pwd
                options.out    ||= '-'
            else
                options.suffix ||= self.suffix
                unless file.nil?
                    options.ext      = File.extname(file)
                    options.srcdir ||= File.dirname(file)
                end
                if options.out
                    options.out = Deplate::Core.file_join(options.dir, options.out)
                    # if options.out != '-'
                    #     options.out = options.dir ? Deplate::Core.file_join(options.dir, options.out) : options.out
                    # end
                elsif file.nil?
                    options.out = '-'
                else
                    options.out = Deplate::Core.get_out_fullname(file, options.suffix, options, :raw => true)
                end
            end
            options
        end

        def formatter_family_members(args={})
            acc = []
            formatter_names = args[:names] || []
            formatter_class = fmt = self
            myname = fmt.myname
            while myname
                acc << myname
                yield(myname) if block_given?
                fmt = fmt.superclass
                myname = fmt.myname
            end
            (formatter_class.related + formatter_names).each do |myname|
                acc << myname
                yield(myname) if block_given?
            end
            acc
        end

        def formatter_related?(name)
            formatter_family_members.include?(name)
        end
    end
 
    @@custom_particles = {}

    attr_reader   :deplate
    attr_reader   :advices
    attr_reader   :expander
    attr_accessor :special_symbols
    attr_accessor :bibentries
    # A hash holding all known document services (names => method).
    attr_accessor :doc_services
    attr_reader   :entities_table

    def initialize(deplate, args={})
        @deplate         = deplate
        @variables       = deplate.variables
        @advices         = args[:advices]      || {}
        @doc_services    = args[:doc_services] || initialize_services
        @inlatex_idx     = 0
        @encodings       = {}
        @symbol_proxy    = nil
        @entities_table  = nil
        @format_advice_backlist = []
        reset!
    end

    def formatter_related?(name)
        self.class.formatter_related?(name)
    end

    def reset!
        @bibentries      = {}
        @open_labels     = []
        # @consumed_labels = []
        # @consumed_ids    = []
    end

    def consumed_labels
        @deplate.output.attributes[:consumed_labels]
    end
    def consumed_labels=(arg)
        @deplate.output.attributes[:consumed_labels] = arg
    end

    def consumed_ids
        @deplate.output.attributes[:consumed_ids]
    end
    def consumed_ids=(arg)
        @deplate.output.attributes[:consumed_ids] = arg
    end

    def retrieve_particle(id, body=nil, specific=false)
        fmt       = specific ? formatter_name : '_'
        particles = @@custom_particles[fmt] ||= {}
        particle  = particles[id]
        if particle
            if body.nil? or particle[:body] == body
                return particle[:class]
            end
        end
        return nil
    end

    def store_particle(id, body, particle, specific=false)
        fmt           = specific ? formatter_name : '_'
        particles     = @@custom_particles[fmt] ||= {}
        particles[id] = {:body => body, :class => particle}
    end

    def def_advice(applicant, agent, args)
        this = @advices[agent] ||= {}
        for type in [:wrap]
            thistype = []
            prc = args[type]
            if prc
                if prc.kind_of?(Proc)
                    thistype << {:applicant => applicant, :prc => prc}
                else
                    raise "Not a Proc: %s" % prc
                end
            end
            unless thistype.empty?
                if this[type]
                    this[type] += thistype
                else
                    this[type] = thistype
                end
            end
        end
        for type in [:before, :around, :after]
            prc = args[type]
            if prc
                log(["Unsupported advice type", type, applicant, prc], :error)
            end
        end
    end
    
    # Run a "service", i.e., a small, mostly autonomous function/method that 
    # usually yields some formatted output.
    def invoke_service(name, args={}, text='')
        method = @doc_services[name]
        if method
            begin
                return send(method, args || {}, text || '')
            rescue Exception => e
                puts e.backtrace[0..10].join("\n")
                log(['Calling service failed', name, e], :error)
            end
        else
            # p "DBG"
            # puts @doc_services.keys.sort.join("\n")
            log(['Unknown service', name], :error)
        end
    end

    def log(*args)
        Deplate::Core.log(*args)
    end
  
    # def canonic_encoding(default=nil, table=@encodings)
    def canonic_encoding(default=nil, table={})
        canonic_enc_name(@variables['encoding'] || default || 'latin1', table)
    end

    def document_encoding(table=@encodings)
        canonic_enc_name(@variables['encoding'] || 'latin1', table)
    end

    def canonic_enc_name(enc, table=@encodings)
        Deplate::Encoding.canonic_enc_name(enc, table)
    end
    
    def output_destination
        @deplate.output.top_heading.destination || @deplate.options.out
    end
    
    def join_blocks(blocks)
        blocks.flatten.compact.join("\n")
    end
    
    def join_inline(strings)
        strings.flatten.compact.join
    end

    def format_particle(agent, invoker, *args)
        if @format_advice_backlist.include?(agent)
            send(agent, invoker, *args)
        else
            # rv = with_agent(agent, Array, invoker, *args)
            # rv.empty? ? format_unknown_particle(invoker) : rv.join
            rv = with_agent(agent, Array, invoker, *args)
            if rv and !rv.empty? and !self.class.naked_agents.include?(agent)
                wa = {}
                wa[:styles] = invoker.styles if invoker.respond_to?(:styles)
                rv = methods.find_all {|m| m =~ /^wrap_formatted_particle_/ }.
                    inject(rv) {|rv, m| send(m, invoker, rv, wa)}
            end
            rv
        end
    end

    def format_particle_as_string(agent, invoker, *args)
        join_inline(format_particle(agent, invoker, *args))
    end

    def format_element(agent, invoker, *args)
        if @format_advice_backlist.include?(agent)
            send(agent, invoker, *args)
        else
            # rv = with_agent(agent, Array, invoker, *args)
            # rv.empty? ? format_unknown(invoker) : join_blocks(rv)
            rv = with_agent(agent, Array, invoker, *args)
            if rv and !rv.empty? and !self.class.naked_agents.include?(agent)
                wa = {}
                wa[:styles] = invoker.styles if invoker.respond_to?(:styles)
                rv = methods.find_all {|m| m =~ /^wrap_formatted_element_/ }.
                    inject(rv) {|rv, m| send(m, invoker, rv, wa)}
            end
            rv    
        end
    end

    def format_element_as_string(agent, invoker, *args)
        format_element(agent, invoker, *args)
    end

    def with_agent(agent, prototype, invoker, *args)
        log(["Call with agent", agent, invoker.class, args], :debug)
        if respond_to?(agent)
            before  = []
            inner   = nil
            after   = []
            stylish = @advices[agent]
            if stylish
                # pre = stylish[:before]
                # if pre
                    # for advice in pre
                        # before << advice[:prc].call(invoker, *args)
                    # end
                # end
                
                inner = self.send(agent, invoker, *args)
                prototype ||= inner.class
                around = stylish[:wrap]
                if around
                    inner = around.inject(inner) do |acc, advice|
                        advice[:prc].call(agent, acc, invoker, *args)
                    end
                end
                
                # post  = stylish[:after]
                # if post
                    # for advice in post
                        # after << advice[:prc].call(invoker, *args)
                    # end
                # end
            else
                args  = args.unshift(invoker)
                begin
                    inner = self.send(agent, *args)
                rescue Exception => e
                    log("We shouldn't be here. If you can track down when this happens, please send an example to the author.", :error)
                    puts "DBG: #{agent}: #{e}"
                    puts e.backtrace[0..10].join("\n")
                    # raise e
                    return nil
                end
                prototype ||= inner.class
            end
            # if prototype == String
                # rv = [before, inner, after].join
            # elsif prototype == Integer
                # rv = [before, inner, after].join.to_i
            # elsif inner.kind_of?(Array)
                # rv = before + inner + after
            # else
                # rv = before + [inner] + after
            # end
            # return rv
            return inner
        else
            invoker.log(['Unknown formatting agent', agent], :error)
            return nil
        end
    end

    def dummy(invoker, *args)
        args
    end
       
    def output(invoker, *body)
        output_at(invoker.doc_type, invoker.doc_slot, *body)
    end

    def output_preferably_at(invoker, type, slot, *body)
        type = defined?(invoker.doc_type) ? invoker.doc_type(type) : type
        slot = defined?(invoker.doc_slot) ? invoker.doc_slot(slot) : slot
        output_at(type, slot, *body)
    end

    def output_empty_at?(type, slot)
        @deplate.output.empty_at?(type, slot)
    end
    
    # def_delegator(:@deplate, :add_at, :output_at)
    def output_at(type, slot, *body)
        log(["Output at", "#{type}@#{slot}", body], :debug)
        @deplate.output.add_at(type, slot, *body)
    end
    
    # def_delegator(:@deplate, :union_at)
    def union_at(type, slot, *body)
        @deplate.output.union_at(type, slot, *body)
    end
    
    # def_delegator(:@deplate, :set_at)
    def set_at(type, slot, *body)
        @deplate.output.set_at(type, slot, *body)
    end
  
    # push *options to variables['classOptions']
    def push_class_option(*options)
        acc = [@deplate.variables["classOptions"]]
        acc += options
        acc.compact!
        @deplate.variables["classOptions"] = acc.join(' ')
    end
    
    # Properly format +text+ as formatter-valid plain text.
    #
    # If +escaped+ is true, +text+ appears in a special context and was 
    # escaped by a backslash or similar.
    #     
    # If a block is given, convert normal text using this block.
    # 
    # Special characters are translated on the basis of @special_symbols.
    def plain_text(text, escaped=false)
        if defined?(@plain_text_rx)
            acc = []
            text.split(@plain_text_rx).each_with_index do |e, i|
                if i.modulo(2) == 0
                    acc << plain_text_recode(e) unless e.empty?
                else
                    r = @special_symbols[e]
                    case r
                    when :identity
                        acc << e
                    when String
                        acc << r
                    when Proc
                        acc << r.call(escaped)
                    else
                        raise "Internal error: Strange symbol replacement for '#{e}': #{r.inspect}"
                    end
                end
            end
            acc.join
        else
            plain_text_recode(text)
        end
    end

    def setup_entities
        unless @entities_table
            @entities_table = []
            enc  = canonic_encoding()
            ents = Deplate::Core.split_list(@deplate.variables['entities'] || 'general')
            for d in Deplate::Core.library_directories(@deplate.vanilla, true, ['ents'])
                for pre in self.class.formatter_family_members << nil
                    for ent in ents
                        f = File.join(d, '%s-%s.entities' % [ent, [pre, enc].compact.join('_')])
                        if File.readable?(f)
                            @entities_table = File.readlines(f).map do |line|
                                line.chomp.split(/\t/)
                            end
                        end
                    end
                end
            end
        end
    end

    def char_by_number(number)
        @entities_table.each do |char, named, numbered|
            if numbered == number
                return char
            end
        end
        return number
    end
    
    def char_by_name(name)
        @entities_table.each do |char, named, numbered|
            if named == name
                return char
            end
        end
        return name
    end

    def check_symbol_proxy
        unless @symbol_proxy
            pre_process
        end
    end

    def symbol_quote(invoker)
        check_symbol_proxy
        @symbol_proxy.symbol_quote(invoker)
    end

    def symbol_gt(invoker)
        check_symbol_proxy
        @symbol_proxy.symbol_gt(invoker)
    end

    def symbol_lt(invoker)
        check_symbol_proxy
        @symbol_proxy.symbol_lt(invoker)
    end

    def symbol_amp(invoker)
        check_symbol_proxy
        @symbol_proxy.symbol_amp(invoker)
    end

    def doublequote_open(invoker)
        check_symbol_proxy
        @symbol_proxy.doublequote_open(invoker)
    end

    def doublequote_close(invoker)
        check_symbol_proxy
        @symbol_proxy.doublequote_close(invoker)
    end

    def singlequote_open(invoker)
        check_symbol_proxy
        @symbol_proxy.singlequote_open(invoker)
    end

    def singlequote_close(invoker)
        check_symbol_proxy
        @symbol_proxy.singlequote_close(invoker)
    end

    def nonbreakingspace(invoker)
        check_symbol_proxy
        @symbol_proxy.nonbreakingspace(invoker)
    end

    # def symbol_paragraph(invoker)
    #     check_symbol_proxy
    #     @symbol_proxy.symbol_paragraph(invoker)
    # end

    def format_symbol(invoker, sym)
        check_symbol_proxy
        @symbol_proxy.format_symbol(invoker, sym)
    end
    
    def format_plain_text(invoker, text=nil, escaped=false)
        text ||= invoker.match
        # <+TBD+> escaped
        plain_text(text, escaped)
    end

    def format_void(invoker, text=nil)
        text || invoker.elt
    end
    
    # Recode normal text for #plain_text
    def plain_text_recode(text, from_enc=nil, to_enc=nil)
        text
    end
    
    def encode_id(id)
        id ? Deplate::Core.clean_name(id) : id
    end
    
    def label_mode
        self.class.label_mode
    end

    def label_once
        self.class.label_once
    end

    def label_delegate
        self.class.label_delegate
    end

    def suffix
        self.class.suffix
    end
    
    def formatter_name
        self.class.myname
    end
    
    def formatter_rx
        self.class.rx
    end

    def setup
    end

    def pre_process
    end

    def prepare
    end

    def matches?(text)
        self.class.formatter_family_members.any? do |fmtname|
            fmt = @deplate.get_formatter_class(fmtname)
            if text[0..0] == '~'
                rv = (fmt.myname =~ Regexp.new(text[1..-1]))
            else
                rv = (text =~ fmt.rx)
            end
            return rv ? true : false
        end
    end

    def format_GET(invoker)
        elt = invoker.elt
        if elt
            elt.format_clip(invoker, Deplate::Element)
        else
            invoker.log("Dropped!", :error)
        end
    end

    def format_LIST(invoker)
        acc  = []
        elt  = invoker.elt
        case elt
        when 'contents'
            elt = 'toc'
        when 'tables'
            elt = 'lot'
        when 'figures'
            elt = 'lof'
        end
        meth = "format_list_of_" + elt
        args = invoker.args
        begin
            if respond_to?(meth)
                acc << send(meth, invoker)
            elsif @deplate.options.listings.is_defined?(elt)
                acc << format_custom_list(invoker, elt)
            else
                log(["Unknown list type", elt.inspect], :error)
            end
            acc << format_pagebreak(invoker) if args["page"]
        rescue StandardError => e
            log(["Formatting on LIST failed", elt.inspect, e, e.backtrace[0..10]], :error)
        end
        join_blocks(acc)
    end

    def format_PAGEBREAK(invoker)
        format_pagebreak(invoker, nil, true)
    end

    def format_CAST(invoker)
        return ''
    end

    def format_ACT(invoker)
        return ''
    end

    def format_direct(invoker, text=nil)
        # invoker.push_styles(['emphasized'])
        invoker.push_styles(['play-direct'])
        "(%s)" % (text || invoker.elt || invoker.text)
    end

    def fill_in_template(invoker)
        invoker.elt
    end
    
    def read_bib(bibfiles)
    end

    def bib_entry(key)
        b = @bibentries[key] || {}
        crossref = b['crossref']
        if crossref
            cb = @bibentries[crossref]
            b.update(cb) {|k, o, n| o} if cb
        end
        return b
    end

    def referenced_bib_entry(invoker, key, text)
        text
    end

    def format_unknown(invoker)
        log(["Unknown element", invoker.class], :error, invoker.source)
        elt = invoker.elt
        if elt.kind_of?(Array)
            elt = elt.join("\n")
        end
        format_verbatim(invoker, elt)
    end

    def format_unknown_particle(invoker)
        return plain_text(invoker.args[:match][0])
    end
    
    def format_unknown_macro(invoker)
        return %{#{plain_text("{")}#{invoker.elt}#{plain_text("}")}}
    end

    def format_heading_close(invoker)
    end
 
    def close_headings(level, &block)
        hds = @deplate.options.headings
        if hds
            acc = []
            loop do
                hd = hds.last
                if hd and level <= hd.level
                    acc << indent_text(format_heading_close(hd), :mult => hd.level - level)
                    if block
                        acc << block.call(hd.level)
                    end
                    hds.pop
                else
                    break
                end
            end
            if acc.empty?
                return nil
            else
                return join_blocks(acc)
            end
        end
    end


    def canonic_mime(type)
        case type
        when 'image/cgm'
        when 'image/g3fax'
        when 'image/gif', 'gif'
            return 'image/gif'
        when 'image/ief', 'ief'
        when 'image/jpeg', 'jpeg', 'jpg', 'jpe'
            return 'image/jpeg'
        when 'image/naplps'
        when 'image/pcx', 'pcx'
        when 'image/png', 'png'
            return 'image/png'
        when 'image/prs.btif'
        when 'image/prs.pti'
        when 'image/svg'+'xml', 'svg', 'svgz'
            return 'image/svg+xml'
        when 'image/tiff', 'tiff', 'tif'
            return 'image/tiff'
        when 'image/vnd.cns.inf2'
        when 'image/vnd.djvu', 'djvu', 'djv'
        when 'image/vnd.dwg'
        when 'image/vnd.dxf'
        when 'image/vnd.fastbidsheet'
        when 'image/vnd.fpx'
        when 'image/vnd.fst'
        when 'image/vnd.fujixerox.edmics-mmr'
        when 'image/vnd.fujixerox.edmics-rlc'
        when 'image/vnd.mix'
        when 'image/vnd.net-fpx'
        when 'image/vnd.svf'
        when 'image/vnd.wap.wbmp', 'wbmp'
        when 'image/vnd.xiff'
        when 'image/x-cmu-raster', 'ras'
        when 'image/x-coreldraw', 'cdr'
        when 'image/x-coreldrawpattern', 'pat'
        when 'image/x-coreldrawtemplate', 'cdt'
        when 'image/x-corelphotopaint', 'cpt'
        when 'image/x-icon', 'ico'
        when 'image/x-jg', 'art'
        when 'image/x-jng', 'jng'
        when 'image/x-ms-bmp', 'bmp'
            return 'image/x-ms-bmp'
        when 'image/x-photoshop', 'psd'
        when 'image/x-portable-anymap', 'pnm'
        when 'image/x-portable-bitmap', 'pbm'
        when 'image/x-portable-graymap', 'pgm'
        when 'image/x-portable-pixmap', 'ppm'
        when 'image/x-rgb', 'rgb'
        when 'image/x-xbitmap', 'xbm'
        when 'image/x-xpixmap', 'xpm'
        when 'image/x-xwindowdump', 'xwd'
            # wmf
            # ps, eps
            # pdf
        end
    end


    def canonic_image_type(type)
        case type
        when 'image/cgm'
        when 'image/g3fax'
        when 'image/gif', 'gif'
            return 'gif'
        when 'image/ief', 'ief'
        when 'image/jpeg', 'jpeg', 'jpg', 'jpe'
            return 'jpg'
        when 'image/naplps'
        when 'image/pcx', 'pcx'
        when 'image/png', 'png'
            return 'png'
        when 'image/prs.btif'
        when 'image/prs.pti'
        when 'image/svg'+'xml', 'svg', 'svgz'
            return 'svg'
        when 'image/tiff', 'tiff', 'tif'
            return 'tif'
        when 'image/vnd.cns.inf2'
        when 'image/vnd.djvu', 'djvu', 'djv'
        when 'image/vnd.dwg'
        when 'image/vnd.dxf'
        when 'image/vnd.fastbidsheet'
        when 'image/vnd.fpx'
        when 'image/vnd.fst'
        when 'image/vnd.fujixerox.edmics-mmr'
        when 'image/vnd.fujixerox.edmics-rlc'
        when 'image/vnd.mix'
        when 'image/vnd.net-fpx'
        when 'image/vnd.svf'
        when 'image/vnd.wap.wbmp', 'wbmp'
        when 'image/vnd.xiff'
        when 'image/x-cmu-raster', 'ras'
        when 'image/x-coreldraw', 'cdr'
        when 'image/x-coreldrawpattern', 'pat'
        when 'image/x-coreldrawtemplate', 'cdt'
        when 'image/x-corelphotopaint', 'cpt'
        when 'image/x-icon', 'ico'
        when 'image/x-jg', 'art'
        when 'image/x-jng', 'jng'
        when 'image/x-ms-bmp', 'bmp'
            return 'bmp'
        when 'image/x-photoshop', 'psd'
        when 'image/x-portable-anymap', 'pnm'
        when 'image/x-portable-bitmap', 'pbm'
        when 'image/x-portable-graymap', 'pgm'
        when 'image/x-portable-pixmap', 'ppm'
        when 'image/x-rgb', 'rgb'
        when 'image/x-xbitmap', 'xbm'
        when 'image/x-xpixmap', 'xpm'
        when 'image/x-xwindowdump', 'xwd'
            # wmf
            # ps, eps
            # pdf
        end
    end


    def include_image(invoker, file, args, *other_args)
        type = args['type'] || File.extname(file).sub(/^\./, '')
        type = canonic_image_type(type)
        meth = "include_image_#{type}"
        if respond_to?(meth)
            return send(meth, invoker, file, args, *other_args)
        else
            include_image_general(invoker, file, args, *other_args)
        end
    end


    ### General
    def_abstract :format_label, :format_figure, :include_image_general, :image_suffixes
    
    ### Elements
    def_abstract :format_note, :format_table, :format_heading, :format_list, 
        :format_break, :format_anchor, :format_paragraph

    ### Regions
    def_abstract :format_verbatim, :format_abstract, :format_quote, 
        :format_header, :format_footer

    ### Commands
    def_abstract :format_title, :format_MAKEBIB, :format_IDX, 
        :format_pagebreak

    ### Particles
    def_abstract :format_emphasize, :format_code, :format_url, :format_wiki
    # def_abstract :format_symbol, :doublequote_open, :doublequote_close, 
    #     :singlequote_open, :singlequote_close

    ### Macros
    def_abstract :format_index, :format_footnote, :format_ref, 
        :format_linebreak, :format_subscript, :format_superscript, :format_stacked, 
        :format_pagenumber

    def element_caption(invoker, name)
        caption = invoker.caption
        if caption
            capAbove = !(caption && caption.args && caption.args.include?("below"))
            if invoker.plain_caption? || caption.args['plain']
                text = caption.elt
            else
                lev  = invoker.level_as_string
                text = %{#{name} #{lev}: #{caption.elt}}
            end
        else
            capAbove = false
            text     = nil
        end
        return [capAbove, text]
    end

    def format_region(invoker)
        invoker.elt.strip
    end

    def format_cite(invoker)
        bib_styler.bib_cite(invoker)
    end

    # Check if ch (a number representing a character) is a multi-byte leader. 
    # This method always returns false unless it is overwritten by some module.
    def multibyte_leader?(ch)
        false
    end

    # Return the first character of string while taking care whether string 
    # starts with a multi-byte sequence. Return the character in upper case if 
    # upcase is true (this usually doesn't work for multi-byte characters.
    def get_first_char(string, upcase=false)
        ch = string[0..0]
        upcase and ch ? ch.upcase : ch
    end
    
    # Return the alphabethically sorted index data.
    # def sort_index_entries(data)
    #     return data.sort do |a,b|
    #         aa = get_first_char(a, true)
    #         bb = get_first_char(b, true)
    #         aa <=> bb
    #     end
    # end
    def sort_index_entries(data)
        return data.sort {|a,b| a[0].upcase <=> b[0].upcase}
    end

    # Return the maximum row size for the table data in elt.
    def table_row_size(elt)
        max = 0
        for row in elt
            i = row.cols.size
            if i > max
                max = i
            end
        end
        max
    end

    def table_empty_cell
        ''
    end

    # Takes an optional block that takes a string as argument and returns 
    # true if we shouldn't wrap the text at this position
    def wrap_text(text, args={})
        margin = args[:margin] || (wm = @deplate.variables['wrapMargin'] and wm.to_i) || 72
        return text if margin == 0
        moreIndent = args[:indent]  || ''
        hanging    = args[:hanging] || 0
        hang_idt   = ' ' * hanging
        block      = args[:check]
        break_at   = args[:break_at]
        acc = []
        rx = /(\n|[[:space:]#{break_at}]+)/
        text.each_line do |text|
            # if text.kind_of?(Array)
            #     log("We shouldn't be here. If you can track down when this happens, please send an example to the author.", :error)
            #     puts caller[0..10].join("\n")
            #     return ''
            # elsif /^\s+$/ =~ text
            if /^\s*$/ =~ text
                acc << nil
                next
            else
                m     = /^(\s*)(.*)$/.match(text.chomp)
                accum = [m[1]]
                idt   = m[1] + moreIndent + hang_idt
                marg  = margin - idt.size
                lmar  = 0
                pos0  = 0
                col0  = 0
                line  = m[2]
                scanner = StringScanner.new(line)
                mpos = scanner.skip_until(rx)
                while mpos
                    pos = scanner.pos
                    col = pos - lmar
                    part = line[lmar, col - scanner.matched_size]
                    good = !(block and block.call(part))
                    if col - scanner.matched_size > marg and good
                        accum << idt unless lmar == 0
                        if pos0 == lmar
                            part = line[lmar, col]
                            accum << part
                            push_linebreak(accum, part)
                            lmar = pos
                            mpos = scanner.skip_until(rx)
                        else
                            part = line[lmar, col0]
                            accum << part
                            push_linebreak(accum, part)
                            lmar = pos0
                            next
                        end
                    else
                        mpos = scanner.skip_until(rx)
                    end
                    if good
                        pos0 = pos
                        col0 = col
                    end
                end
                part = line[lmar, col0]
                # if /\S/ =~ part
                    accum << idt unless lmar == 0
                    # p "DBG wrap_text", line
                    # p !(block and block.call(part))
                    if line.size - lmar - 1 > marg and pos0 != lmar and !(block and block.call(part))
                        # p "DBG1", part
                        accum << part
                        push_linebreak(accum, part)
                        accum << idt << line[pos0, line.size - pos0]
                    else
                        part = line[lmar, line.size - lmar]
                        # p "DBG2", part
                        accum << part
                    end
                # end
                acc << accum.join
            end
            end
        return acc.join("\n")
    end

    def push_linebreak(accum, part, add_blank=true)
        if part
            accum << ' ' if add_blank and /\s$/ !~ part
            accum << "\n"
        end
    end
  
    def prelude(name)
        @deplate.variables[name]
    end
    
    # Format the Inlatex region
    def format_inlatex(invoker)
        args   = invoker.args
        inline = args['inline']
        args['h'] ||= (args['inlineLatexHeight'] || args['inlatexHeight']) if inline
        acc    = []
        elt    = invoker.elt
        if elt
            elt.each do |i|
                acc << format_element(:format_figure, invoker, inline, i)
            end
        else
            invoker.log(['Empty element', 'inlatex'], :error)
        end
        join_blocks(acc)
    end
            
    # Format the ltx macro
    def format_ltx(invoker, other_args={})
        args = invoker.args
        acc  = []
        args['h']   ||= (args['inlineLatexHeight'] || other_args['h'])
        args['alt'] ||= invoker.text
        args['style'] = 'latex'
        inlatex = invoker.elt
        if !inlatex or inlatex.empty?
            acc << invoker.text
        else
            for i in inlatex
                # acc << @deplate.formatter.include_image(invoker, i, args, true)
                acc << format_element(:format_figure, invoker, true, i)
            end
        end
        return acc.flatten.join("\n")
    end

    # Format the math macro
    alias :format_math :format_ltx
  
    def bare_latex_formula(text)
        m = /^(\\\[|\$)(.*?)(\\\]|\$)$/.match(text)
        if m
            return [m[1] == '\\[', m[2]]
        else
            log(['Internal error', text], :error)
            return nil
        end
    end

    # Process inline latex. The file names of the output are saved as an 
    # array in <tt>invoker.elt</tt>.
    def inlatex(invoker)
        pkgs, body = inlatex_split(invoker.accum)
        id      = inlatex_id(invoker)
        sfx     = invoker.args['sfx'] || @deplate.variables['ltxSfx'] || inlatex_sfx
        currDir = Dir.pwd
        @deplate.in_working_dir do
            ftex    = id + '.tex'
            flog    = id + '.log'
            faux    = id + '.aux'
            fdvi    = id + '.dvi'
            fps     = id + '.ps'
            checkOW = true

            case sfx
            when 'ps'
                device  = nil
                fout    = fps
                checkOW = false
            when 'pdf'
                device  = 'pdfwrite'
                fout    = id + '.*.pdf'
            when 'jpeg', 'jpg'
                device  = 'jpeg'
                fout    = id + '.*.jpeg'
            when "png"
                device  = "png"
                fout    = id + ".png"
            else
                raise "Unknown device/suffix: #{sfx}"
            end

            pointsize = invoker.args['pointsize'] || 
                @deplate.variables['latexPointsize'] || '10'
            acc = [
                "\\documentclass[#{pointsize}pt,a4paper,notitlepage]{article}",
                "\\usepackage{amsmath}",
                "\\usepackage{amsfonts}",
                "\\usepackage{amssymb}",
                # "\\usepackage{mathabx}",
            ]
            acc += pkgs
            acc << "\\begin{document}" << "\\pagestyle{empty}"
            acc += body
            acc << "\\end{document}"

            if Deplate::Region.check_file(invoker, fout, ftex, acc)
                invoker.log(['Files exist! Using', fout], :anyway)
            else
                if checkOW and !@deplate.options.force
                    for f in [ftex, flog, faux, fdvi, fout]
                        if !Dir[f].empty?
                            raise "Please delete '#{f}' or change the id before proceeding:\n#{invoker.accum.join("\n")}"
                        end
                    end
                end

                acc = acc.join("\n")

                Deplate::External.write_file(invoker, ftex) {|io| io.puts(acc)}
                inlatex_process_latex(invoker, ftex, faux, flog)
                if block_given?
                    yield(invoker, device, fdvi, fps, fout)
                else
                    case device
                    when "png"
                        inlatex_process_dvi_png(invoker, fdvi, fout) if File.exist?(fdvi)
                    else
                        inlatex_process_dvi(invoker, fdvi, fps) if File.exist?(fdvi)
                        if device
                            inlatex_process_ps(invoker, device, fps, fout, invoker.args)
                        elsif fps != fout
                            File.rename(fps, fout)
                        end
                    end
                end
            end

            invoker.elt = Dir[fout]
            if invoker.elt.empty?
                code = invoker.accum.join("\n")
                invoker.log(["Conversion if Inline LaTeX failed", code], :error)
            end
        end
    end

    def inlatex_id(invoker, last=false)
        id = invoker.args["id"]
        unless id
            unless last
                @inlatex_idx += 1
            end
            id = @deplate.auxiliary_auto_filename('ltx', @inlatex_idx, invoker.accum)
            invoker.log(["No ID given", invoker.accum])
        end
        id
    end

    def inlatex_process_latex(invoker, ftex, faux, flog)
        latex2dvi(invoker, ftex, faux, flog)
    end

    def inlatex_process_dvi(invoker, fdvi, fps)
        dvi2ps(invoker, fdvi, fps)
    end

    def inlatex_process_dvi_png(invoker, fdvi, fout)
        dvi2png(invoker, fdvi, fout)
    end

    def inlatex_process_ps(invoker, device, fps, fout, args)
        ps2img(invoker, device, fps, fout, args) if File.exist?(fps)
    end
    
    # Divert lines in invoker#accum to the preamble or the body.
    def inlatex_split(accum)
        pkgs = []
        body = []
        for l in accum.join("\n")
            l = inlatex_clean(l)
            if l =~ /^\s*\\(usepackage|input)\s*(\[.*?\])?\s*\{.+?\}\s*$/
                pkgs << l.chomp
            elsif l =~ /%%%\s*$/
                pkgs << l.chomp
            else
                body << l.chomp
            end
        end
        return pkgs.uniq, body
    end
    
    rx = self.blacklist_latex.collect! do |c|
        if c =~ /^\\(.+)$/
            "\\\\\\s*#$1\\b"
        elsif c =~ /\w$/
            # "(\\\\\\s*)?\\b#{Regexp.escape(c)}\\b"
            "\\\\\\s*#{Regexp.escape(c)}\\b"
        else
            Regexp.escape(c)
        end
    end
    INLATEX_RX = Regexp.new(rx.join('|'))

    def inlatex_clean(line)
        line = line.chomp
        unless @deplate.is_allowed?('t')
            line.gsub!(INLATEX_RX, '+++disabled+++')
        end
        line
    end
    
    # The default suffix/device to be used for inlatex output.
    def inlatex_sfx
        'jpeg'
    end

    def latex2dvi(invoker, ftex, faux, flog)
        if Deplate::External.latex(invoker, ftex) and @deplate.options.clean
            for i in [faux, flog]
                if File.exist?(i)
                    File.delete(i)
                    invoker.log(["Deleting", i])
                end
            end
        end
    end

    def dvi2ps(invoker, fdvi, fps, other_options=nil)
        # -Pwww 
        if Deplate::External.dvi2ps(invoker, fdvi, fps, other_options) and @deplate.options.clean
            File.delete(fdvi) if @deplate.options.clean
            invoker.log(["Deleting", fdvi])
        end
    end

    def dvi2png(invoker, fdvi, fout, other_options=nil)
        if Deplate::External.dvi2png(invoker, fdvi, fout, other_options) and @deplate.options.clean
            File.delete(fdvi) if @deplate.options.clean
            invoker.log(["Deleting", fdvi])
        end
    end

    def ps2img(invoker, device, fps, fout, args)
        if Deplate::External.ps2img(invoker, device, fps, fout, args) and @deplate.options.clean
            File.delete(fps)
            invoker.log(["Deleting", fps])
        end
    end

    def formatted_block(env, text, opts=nil, args=nil, no_id=false, no_indent=false)
        text = indent_text(text) unless no_indent
        return join_blocks([get_open(env, opts, args, :no_id => no_id), text, get_close(env, args)])
    end

    def_abstract :get_open, :get_close

    def formatted_inline(env, text, opts=nil, args=nil, no_id=false)
        return join_inline([get_open(env, opts, args, :no_id => no_id), text, get_close(env, args)])
    end

    def formatted_single(env, opts=nil, args=nil, no_id=false)
        return get_open(env, opts, args, :single => true, :no_id => no_id)
    end

    def indent_text(text, args={})
        if text
            mult    = args[:mult] || 1
            shift   = args[:shift]
            hanging = args[:hanging]
            indent  = args[:indent] || format_indent(mult, shift)
            acc = []
            text.each_line do |l|
                rv = '%s%s' % [indent, l.chomp]
                if hanging
                    indent = args[:indenttail] || \
                        if args[:indent]
                            args[:indent] + 
                                case hanging
                                when Integer
                                ' ' * hanging
                                else
                                '    '
                                end
                        else
                            format_indent(mult + 1, shift)
                        end
                    hanging = false
                end
                acc << rv
            end
            return acc.join("\n")
        end
    end

    def_service('object') do |args, text|
        id = args['id']
        if id
            return @deplate.object_by_id(id)
        elsif args['array']
            text = args['array']
            sep = args['sep']
            if sep
                sep  = sep ? Regexp.escape(sep) : '\\s+'
            else
                sep = args['rx']
            end
            if sep
                return text.split(Regexp.new(sep))
            else
                log('No separator', :error)
            end
        end
    end

    def_service('output_filename') do |args, text|
        output_destination
    end
    
    def_service('output_basename') do |args, text|
        sfx = args['sfx']
        if sfx
            File.basename(output_destination, sfx)
        else
            File.basename(output_destination)
        end
    end
    
    # <+TBD+>
    # def_service('format') do |args, text|
    #     id = args['id'] || text
    #     # o  = @variables[id]
    #     o  = object_by_id(id)
    #     if o
    #         o.format_as_string
    #     end
    # end

    def stepwise_prepare
        # @deplate.output.attributes[:stepwiseIdx] ||= 0
    end

    def stepwise_next
        stepwise_prepare
        @deplate.output.attributes[:stepwiseIdx] += 1
    end


    protected
    def initialize_services
        services = {}
        return services
    end

    # def clean_tags(text)
    #     if text
    #         t = text.gsub(/\<[^>]*?\>/, '')
    #         t.gsub!(/^\s*$/, '')
    #         t.gsub!(/^\n\s*/, '')
    #         t.gsub!(/\n\s*$/, '')
    #         t
    #     end
    # end

    def clean_tags(text, *tags)
        if text
            if tags.empty?
                t = text.gsub(/\<[^>]*?\>/, '')
            else
                # tags = tags.empty? ? '\w+' : tags.join('|')
                tags = tags.join('|')
                t = text.gsub(/<(#{tags}).*?\/>|<(#{tags}).*?>.*?<\/\1>/, '')
            end
            t.gsub!(/^\s*$/, '')
            t.gsub!(/^\n\s*/, '')
            t.gsub!(/\n\s*$/, '')
            t
        end
    end

    def format_custom_list(invoker, elt)
        listing = @deplate.options.listings.get(elt, true)
        props   = listing[:props]
        format_list_of(invoker,
                       :title => props['title'],
                       :prefix => props['prefix'] || elt,
                       :data  => listing[:value],
                       :flat  => props['flat'],
                       :style => (props['style'] || props['prefix'])
                      )
    end
    
    def format_list_of(invoker, other_args)
        args   = invoker.args
        name   = other_args[:title]
        prefix = other_args[:prefix]
        data   = other_args[:data]
        unless data
            list = other_args[:listing]
            data = invoker.deplate.options.listings.get(list)
            unless data
                invoker.log(['Unknown list', list], :error)
            end
        end
        name = args['title'] || name
        id   = (name || prefix).gsub(/\W/, '_')
        
        acc  = []
        consume_label(id, true)
        consume_label("#{id}Block", true)
        acc << listing_prematter(invoker, other_args, id)
        unless args['plain'] || args['noTitle']
            acc << listing_title(invoker, other_args, name)
        end
        
        ll = 1
        levels = args['levels']
        if levels
            range_from, range_to, rest = levels.split(/\.\./)
            if rest
                log(['Malformed range', levels], :error)
            end
        end
        range_from ||= args['min']
        if range_from
            range_from = range_from.to_i
        end
        range_to ||= args['max']
        if range_to
            range_to = range_to.to_i
        end
        top = args['top']
        if top
            top = /^#{Regexp.escape(top)}/
        end
        sub = args['sub']
        if sub
            sub = /^#{Regexp.escape(invoker.level_as_string)}\./
        end
        accData = []
        for elt in data
            if elt.nil? or elt.args['noList']
                next
            end
            if range_from and elt.level < range_from
                next
            end
            if range_to and elt.level > range_to
                next
            end
            if top and elt.level_as_string !~ top
                next
            end
            if sub and elt.level_as_string !~ sub
                next
            end
            title = block_given? ? yield(elt) : elt.element_caption
            level = other_args[:flat] ? 1 : elt.level
            accData << listing_item(invoker, args, prefix, title, elt, level, other_args)
        end
        acc << printable_list(invoker, accData)
        acc << listing_postmatter(invoker, other_args)
        join_blocks(acc)
    end

    def_abstract :listing_prematter, :listing_postmatter, :listing_title, \
        :listing_item

    def consume_label(label, warn=false)
        if !label
            return false
        elsif consumed_labels.include?(label)
            log(['Duplicate label'], label, :error) if warn
            return false
        else
            consumed_labels << label
            return true
        end
    end
    
    def use_id(args, opts={}, set=true)
        if args
            set &&= !args[:id]
        else
            args = {}
        end
        id = opts['id'] || args[:id] || args['id']
        # || args['label']
        args[:id] = id if set
        id
    end
    
    def use_labels(args, labels, opts={})
        args   ||= {}
        labels   = labels ? labels.dup : []
        id = use_id(args, opts)
        l  = args['label']
        labels << l if l
        # i  = opts[:invoker]
        # if i
        #     labels += i.label
        # end
        if opts[:with_id]
            labels << id
        elsif id
            labels.delete(id)
        end
        labels.delete_if {|e| consumed_labels.include?(e)}
        labels.flatten!
        labels.compact!
        labels.uniq!
        self.consumed_labels += labels unless labels.empty?
        return labels
    end

    def format_indent(level, shift=false)
        if level < 0
            log(['Negative indentation level', level], :error)
            return ''
        else
            l = level * 2
            # l += 1 if shift
            return '  ' * l
        end
    end
    
    def keywords
        kw = @deplate.variables['keywords']
        if kw.kind_of?(Array)
            kw
        elsif kw.kind_of?(String)
            Deplate::Core.split_list(kw, ';', ',')
        elsif kw
            log(["Shouldn't be here", kw, kw.class], :error)
        else
            nil
        end
    end
   
    # Create @plain_text_rx, which contains the keys of @special_symbols 
    # in a group. This rx will be used by #plain_text.
    def build_plain_text_rx
        @plain_text_rx = Regexp.new('(%s)' % @special_symbols.keys.collect {|x| Regexp.escape(x)}.join('|'))
    end


    ################################################ Bibliography {{{1
    def bib_styler
        style = @deplate.variables['bibStyle']
        @deplate.bib_styler(style)
    end
   
    def simple_bibtex_reader(bibfiles)
        acc = []
        for b in bibfiles
            b = File.expand_path(b)
            unless File.exist?(b)
                b = Deplate::External.kpsewhich(self, b)
                if b.empty?
                    next
                end
            end
            File.open(b) {|io| acc << io.read}
        end
        text = acc.join("\n")
        @configuration   = self
        @crossreferenced = []
        entries, prelude = simple_bibtex_parser(text)
        @bibentries.update(entries)
    end

    def simple_bibtex_parser(text, strings_expansion=true)
        prelude = []
        strings = {}
        entries = {}
        lineno  = 1
        # m = /^\s*(@(\w+)\{(.*?)\})\s*(?=(^@|\z))/m.match(text)
        while (m = /^\s*(@(\w+)\{(.*?))\s*(?=(^@|\z))/m.match(text))
            text  = m.post_match
            body  = m[0]
            type  = m[2]
            inner = m[3]
            case type.downcase
            when 'string'
                prelude << body
                mi = /^\s*(\S+?)\s*=\s*(.+?)\s*\}?\s*$/m.match(inner)
                r = mi[2]
                if r =~ /^(".*?"|'.*?'|\{.*?\})$/
                    r = r[1..-2]
                end
                strings[mi[1]] = r
            else
                mi = /^\s*(\S+?)\s*,(.*)$/m.match(inner)
                id = mi[1]
                e  = mi[2]
                # arr = e.scan(/^\s*(\w+)\s*=\s*(\{.*?\}|\d+)\s*[,}]\s*$/m)
                arr = e.scan(/^\s*(\w+)\s*=\s*(\{.*?\}|".*?"|\d+)\s*[,}]\s*$/m)
                entry = {}
                arr.each do |var, val, rest|
                    # EXPERIMENTAL: something like author={{Top Institute}} didn't work. I'm not sure though if this is able to deal with the last field in a bibtex entry correctly
                    # n = /^\s*\{(.*?)\}\s*($|\}\s*\z)/m.match(val)
                    if (n = /^\s*\{(.*?)\}\s*$/m.match(val))
                        val = n[1]
                    elsif (n = /^\s*"(.*?)"\s*$/m.match(val))
                        val = n[1]
                    end
                    if strings_expansion and strings[val]
                        val = strings[val]
                    end
                    if (oldval = entry[var])
                        if oldval != val
                            meth = "duplicate_field_#{var}"
                            if @configuration.respond_to?(meth)
                                $stderr.puts "Resolve duplicate fields with mismatching values: #{id}.#{var}" if $VERBOSE
                                val = @configuration.send(meth, oldval, val)
                            else
                                $stderr.puts "Cannot resolve duplicate fields with mismatching values: #{id}.#{var}"
                            end
                        end
                    end
                    entry[var] = val
                    case var
                    when 'crossref'
                        @crossreferenced << val
                    end
                end
                entry['_lineno'] = lineno.to_s
                entry['_type']   = type
                entry['_id']     = id
                entry['_entry']  = body
                if entries[id]
                    if entries[id] != entry
                        $stderr.puts "Duplicate key, mismatching entries: #{id}"
                        if $DEBUG
                            $stderr.puts entries[id]['_entry'].chomp
                            $stderr.puts '<=>'
                            $stderr.puts entry['_entry'].chomp
                            $stderr.puts
                        end
                    end
                    entries[id].update(entry)
                else
                    entries[id] = entry
                end
            end
            lineno += (m.pre_match.scan(/\n/).size + body.scan(/\n/).size)
        end
        if text =~ /\S/
            $stderr.puts "Trash in bibtex input: #{text}" if $VERBOSE
        end
        return entries, prelude.join
    end

    def duplicate_field_author(oldval, val)
        [oldval, val].join(' and ')
    end

    def duplicate_field_abstract(oldval, val)
        [oldval, val].join("\n")
    end

    def duplicate_field_url(oldval, val)
        [oldval, val].join(' ')
    end

    def duplicate_field_keywords(oldval, val)
        (oldval.split(/[;,]\s*/) | val.split(/[;,]\s*/)).join(', ')
    end

    def cited_keys
        @deplate.options.citations.collect {|c| c.elt}.flatten.uniq
    end
    
    def format_bibliography(invoker)
        acc  = []
        for k in cited_keys
            b  = bib_entry(k)
            bb = format_bib_entry(invoker, k, b)
            i  = encode_id(k)
            l  = format_label(invoker, :string, [i])
            if block_given?
                acc << [yield(i, l, bb), bb]
            else
                acc << [bb, bb]
            end
        end
        acc = acc.sort {|a,b| a[1] <=> b[1]}
        acc.collect! {|e| e[0]}
        join_blocks(acc)
    end

    def format_bib_entry(invoker, key, bibdef)
        if bibdef.empty?
            # text = "#{key}??? (#{@deplate.msg('Unknown bib entry')})"
            text = "#{key}???"
        else
            text = bib_styler.bib_format(bibdef)
        end
        return @deplate.parse_and_format_without_wikinames(invoker, text)
    end

    def simple_latex_reformat(text, remove_brackets=false)
        text.gsub!(/^\{(.*)\}$/, "\\1") if remove_brackets
        text.gsub!(/\s+/m, " ")
        text.gsub!(/``/, %{"})
        text.gsub!(/''/, %{"})
        text.gsub!(/`/,  %{'})
        text.gsub!(/'/,  %{'})
        # text.gsub!(/--/, %{--})
        text.gsub!(/\\([$&%#_{}^~|])(\{\})?/, "\\1")
        return text
    end

    # this is the general function used for formatting lists of any kind; it 
    # relies on #format_list, #format_indent and #format_list_item to 
    # do the actual output
    def printable_list(invoker, list=nil)
        list  ||= invoker.elt
        unless list.nil? or list.empty?
            list_tags = {
                :levels   => [],
                :types    => [],
                :end_tags => []
            }
            accum    = []
            # level0  = list.sort {|a,b| a.level <=> b.level}[0].level
            level0   = list.min do |a,b|
                if a.level and b.level
                    a.level <=> b.level
                elsif a
                    1
                else
                    -1
                end
            end.level
            ind      = 0
            max      = list.size - 1

            list.each_with_index do |i, idx|
                # :listtype, :type, :level, :item, :body
                t = i.type
                s = list_subtype(t, i)
                c = [i.listtype, s]
                l = i.level
                if last_listtype(list_tags)
                    special = ['Paragraph', 'Container'].include?(t)
                    # there is a list environment, so this isn't the first item
                    if last_level(list_tags) and l != last_level(list_tags)
                        if l < last_level(list_tags)
                            # close a nested list
                            ind = printable_close_lists_until(invoker, list_tags, accum, ind, l)
                        elsif l > last_level(list_tags) and !special
                            # open a new nested list
                            # p "DBG           --- 1054: #{c} != #{last_listtype(list_tags)}"
                            ind = printable_open_list(invoker, list_tags, accum, c, ind, l, s)
                            list_tags[:end_tags] << nil
                        end
                    end
                    if last_level(list_tags) and last_listtype(list_tags) and c != last_listtype(list_tags) and !special
                        if l <= last_level(list_tags)
                            # close the previous list and start a new one
                            ind = printable_list_close_endtag(invoker, list_tags, accum, ind)
                            # p "DBG             ---- #{last_listtype(list_tags)} #{t}"
                        end
                        if c != last_listtype(list_tags) and l <= last_level(list_tags)
                            # p "DBG           --- 1067: #{c} != #{last_listtype(list_tags)}"
                            ind = printable_close_list(invoker, list_tags, accum, ind)
                            ind = printable_open_list(invoker, list_tags, accum, c, ind, l, s)
                            list_tags[:end_tags] << nil
                        end
                    end
                else
                    # start a new list
                    ind = printable_open_list(invoker, list_tags, accum, c, ind, l, s)
                end
                if list_tags[:levels].empty? and idx < max
                    # something weired happened (e.g. the previous list item was 
                    # deeper nested, but this item doesn't continue anything -- 
                    # which should probably considered as a syntax error anyway)
                    invoker.log(['Malformed list hierarchy', last_listtype(list_tags), idx], :error)
                    ind = printable_open_list(invoker, list_tags, accum, c, ind, l, s)
                end
                ind = printable_list_item(invoker, list_tags, accum, t, ind, l, i)
                if i.label and !i.label.empty?
                    lab = format_label(invoker, :string, i.label)
                    if lab
                        accum[-1] += lab
                    end
                end
            end
            
            # close all open tags & lists
            while !list_tags[:end_tags].empty?
                ind = printable_list_close_endtag(invoker, list_tags, accum, ind)
            end
            while !list_tags[:levels].empty?
                ind = printable_close_list(invoker, list_tags, accum, ind)
            end
            if ind < 0
                invoker.log(['Malformed list or internal error', invoker.class], :error)
            end

            accum.delete_if {|e| e == :empty}
            return join_blocks(accum)
        else
            return ''
        end
    end

    def last_level(list_tags)
        list_tags[:levels].last
    end

    def last_listtype(list_tags)
        list_tags[:types].last
    end
    
    def list_subtype(type, item)
        case type
        when "Ordered"
            if item.item =~ /^[A-Z]\.?$/
                return "A"
            elsif item.item =~ /^[a-z?@]\.?$/
                return "a"
            else
                return "1"
            end
        # when "Itemize"
        #     return nil
        # when "Description"
        #     return nil
        # when 'Task'
        #     return nil
        # when "Paragraph"
        #     return nil
        # when 'Container'
        #     return nil
        else
            if item.opts and item.opts[:subtype]
                return item.opts[:subtype]
            else
                return nil
            end
            # raise "Unknown list type: #{type}"
        end
    end

    def printable_list_item(invoker, list_tags, accum, type, indentation, level, item)
        case type
        when 'Paragraph'
            args = {}
            if @list_last_type == 'Container'
                args[:follow_container] = true
            end
            acc, etag = format_list_item(invoker, type, indentation, item, args)
            accum << acc
        when 'Container'
            item_copy  = item.dup
            # idt       = item_copy.body.indentation
            # idt_level = item_copy.body.indentation_level
            idt_mode   = invoker.args['indentation']
            if item_copy.body
                idt_mode ||= item_copy.body.class.indentation_mode.to_s
                item_copy.body = item_copy.body.format_current
            end
            case idt_mode
            when 'auto'
                item_copy.body = indent_text(item_copy.body, :mult => indentation)
            when 'none'
            else
                invoker.log(['Unknown indentation mode', idt_mode], :error)
            end
            # p "DBG #{' ' * level} Container (#{list_tags[:types]} #{@list_levels})"
            acc, etag = format_list_item(invoker, type, indentation, item_copy)
            accum << acc
        else
            indentation = printable_list_close_endtag(invoker, list_tags, accum, indentation)
            # p "DBG #{' ' * level} Item (#{list_tags[:types]} #{@list_levels})"
            acc, etag = format_list_item(invoker, type, indentation, item)
            list_tags[:end_tags] << [etag, level, indentation]
            accum << acc
            indentation += 1
        end
        @list_last_type = type
        indentation
    end
    
    def printable_close_lists_until(invoker, list_tags, accum, ind, level)
        begin
            ind = printable_list_close_endtag(invoker, list_tags, accum, ind)
            ind = printable_close_list(invoker, list_tags, accum, ind)
        end until list_tags[:levels].empty? or list_tags[:levels].last <= level
        ind
    end
    
    def printable_close_list(invoker, list_tags, accum, ind)
        ind -= 1
        lev  = list_tags[:levels].pop
        tp, sp = list_tags[:types].pop
        # p "DBG #{' ' * (lev || 1)}>close #{lev} #{tp} #{sp} #{caller[0]}"
        le = format_list_env(invoker, tp, ind, :close, sp)
        accum << le if le
        ind
    end

    def printable_open_list(invoker, list_tags, accum, type, ind, level, subtype=nil)
        t, s = type
        le = format_list_env(invoker, t,  ind, :open, subtype)
        accum << le if le
        ind += 1
        list_tags[:levels] << level
        list_tags[:types]  << type
        # p "DBG #{' ' * (level || 1)}<open #{level} #{type} #{subtype} #{caller[0]}"
        ind
    end

    def printable_list_close_endtag(invoker, list_tags, accum, ind)
        tag, level, ind0 = list_tags[:end_tags].pop
        if tag
            while list_tags[:levels].last and list_tags[:levels].last > level
                ind = printable_close_list(invoker, list_tags, accum, ind)
            end
            accum << tag unless tag == :none
        end
        return ind0 || ind
    end

    def list_item_explicit_value(item, explicit=false)
        if @deplate.variables['noExplicitNumbering']
            nil
        elsif explicit or item.explicit and item.item and !item.item.empty?
            item.item
        else
            nil
        end
    end

    def use_image_filename(filename, args={})
        unless args['noGuess'] or args[:raw]
            fext  = File.extname(filename)
            fname = fext.empty? ? filename : filename[0..(-1 - fext.size)]
            for sfx in image_suffixes
                fs  = [fname, sfx].join
                ff  = @deplate.auxiliary_filename(fs)
                fff = @deplate.auxiliary_filename(fs, true)
                if File.exist?(fff)
                    return ff
                end
            end
        end
        return filename
    end

end

