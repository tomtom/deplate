# encoding: ASCII
# regions.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     08-Mai-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.1850


class Deplate::Region < Deplate::Element
    @@regions = {}
    
    class_attribute :line_cont, true

    class << self
        def regions
            @@regions
        end

        def register_as(name, c=self)
            @@regions[name] = self
        end

        def set_line_cont(val=true)
            self.line_cont=val
        end

        def check_file(container, out, file, source)
            if Dir[out].empty?
                container.log(['Output not found', out, Dir.pwd])
                return false
            elsif file and source
                if File.exist?(file)
                    accum = File.open(file) {|io| io.read}.split(/[\n\r]+/)
                    clean_strings(accum)
                    clean_strings(source)
                    if accum === source
                        container.log(['Output exists and source matches', file])
                        return true
                    else
                        container.log(['Source has changed', file, accum.size, source.size])
                        # p "DBG", accum, source
                        # puts caller[0..10].join("\n")
                        for i in 0..[accum.size, source.size].max
                            unless accum[i] === source[i]
                                container.log('%S != %S', [accum[i], source[i]])
                            end
                        end
                    end
                else
                    container.log(['Source not found; assume that output is okay', file])
                    return true
                end
            end
            container.log(['Output needs updating', file])
            return false
        end
        
        def clean_strings(strings)
            strings.delete('')
            strings.each {|l| l.chomp!}
        end

        def deprecated_regnote(invoker, args, regNote, arg='@note')
            # if !@args.has_key?(arg) or (!@args[arg] and @regNote)
            if !args.has_key?(arg)
                if regNote and !regNote.empty?
                    invoker.log(['Deprecated region syntax: Use argument instead', arg, regNote]
                                # , :anyway
                               )
                    # puts caller[0..10].join("\n")
                end
                args[arg] = regNote
            end
            args[arg]
        end

    end
    
    def setup(region=nil)
        if region
            @region = region
            @args.merge!(region.args)
            update_args
        end
    end

    def finish_accum
        if @region
            unify_now(@region)
            @regNote = @region.regNote ? @region.regNote.strip : ''
            @accum   = @region.accum
        else
            @regNote = ''
        end
        if defined?(@indent)
            rx = /^#{@indent}/
            @accum.each do |l|
                l.gsub!(rx, "")
            end
        end
    end
    
    def finish
        finish_accum
        return super
    end

    def format_compound
        acc = []
        prototype = @expected || @prototype.class
        for e in @elt
            e.match_expected(prototype, self) # if prototype
            # e.doc_type = doc_type
            # e.doc_slot = doc_slot
            acc << e.format_contained(self)
        end
        fmt = self.class.formatter2 || self.class.formatter
        if fmt
            @elt = @deplate.formatter.join_blocks(acc)
            return format_contained(self, fmt)
        else
            return @deplate.formatter.join_blocks(acc)
        end
    end

    def deprecated_regnote(arg='@note')
        Deplate::Region.deprecated_regnote(self, @args, @regNote, arg)
    end
end


class Deplate::Region::SecondOrder < Deplate::Region
    def finish
        finish_accum
        @elt = @deplate.parsed_array_from_strings(@accum, @source.begin, @source.file)
        return self
    end

    def process
        process_etc
        @elt = @elt.collect {|e| e.process}.compact
        @prototype = @elt.first
        unless label_mode == :none
            @prototype.put_label(@label) if @prototype
        end
        return self
    end

    def push_styles(*args)
        @elt.each {|e| e.push_styles(*args)}
    end
    
    alias format_special format_compound
end


module Deplate::Regions; end

class Deplate::Regions::UNKNOWN < Deplate::Region
    register_as 'UNKNOWN'
    set_formatter :format_unknown

    def finish
        # finish_accum
        # @elt = @accum
        # return self
        ### !!! We drop it
        return nil
    end

    def process
        return self
    end

    def format_special
        @deplate.formatter.format_unknown(self)
    end
end


class Deplate::Regions::Var < Deplate::Region
    register_as 'Doc'
    register_as 'Var'
    set_line_cont false

    def finish
        finish_accum
        id = deprecated_regnote('id')
        Deplate::Command::VAR.set_variable(@deplate, id, @accum, @args, @source)
        return nil
    end
end


class Deplate::Regions::Native < Deplate::Region
    register_as 'Native'
    register_as 'Ins'
    set_line_cont false
    self.label_mode = :once

    def finish
        finish_accum
        @elt = @accum
        if @args['template']
            @elt = filter_template(@elt)
        end
        return self
    end

    def process
        process_etc
        return self
    end

    def format_special
        case @elt
        when Array
            @elt.join("\n")
        else
            puts "TBD DBG This shouldn't be @elt.class=#{@elt.class}. Please report."
            puts @elt
            @elt
        end
    end
end


class Deplate::Regions::Write < Deplate::Regions::Native
    register_as 'Write'
    self.label_mode = :none
    
    def finish
        unless @args['noTemplate']
            @args['template'] = true
        end
        # @vars = @deplate.variables.dup
        super
    end
    
    def format_special
        # @elt = Deplate::Template.new(:template  => @elt,
        #                              :source    => @source,
        #                              :container => self)
        # Deplate::Define.let_variables(@deplate, @vars) do
        #     @elt = @elt.fill_in(@deplate, :source => @source)
        # end
        # @elt = @elt.join("\n")
        # @elt = filter_template(@elt, @vars, :container => self).join("\n")
        fname = @args['file'] || @args['id']
        if fname == '-' or @deplate.is_allowed?(['w', 'W'], :logger => self)
            if fname
                if fname == '-'
                    # fname = 2
                    puts @elt
                else
                    unless @deplate.is_allowed?('W')
                        fname = File.basename(fname)
                    end
                    fname = Deplate::Core.get_out_fullname(fname, nil, @deplate.options)
                    sfx   = @args['suffix'] || @args['sfx']
                    fname = [fname, sfx.gsub(/[^[:alnum:].]/, '_')].join('.') if sfx
                    mode  = @args['append'] ? 'a' : 'w'
                    @deplate.write_file(fname, mode) do |io|
                        io.puts(@elt)
                    end
                end
            else
                log(['No filename'], :error)
            end
        end
    end

end


class Deplate::Regions::Code < Deplate::Regions::Native
    register_as 'Code'
    # set_line_cont false
    self.label_mode = :once

    @@code_idx = 0
    @general_highlighter = {}
    @syntax_highlighter  = {}
    @options = Hash.new {|h, k| h[k] = {}}

    class << self
        attr_reader :syntax_highlighter, :general_highlighter, :options

        def highlighter_option(agent, options)
            @options[agent].merge!(options)
        end

        def add_highlighter(syntax, format, agent)
            case syntax
            when Array
                syntax.each do |syn|
                    add_highlighter(syn, format, agent)
                end
            else
                if syntax
                    @syntax_highlighter[syntax] ||= []
                    @syntax_highlighter[syntax] << [format, agent]
                else
                    @general_highlighter[format] = agent
                end
            end
        end
    end

    def setup(region)
        super
        @syntax = @deplate.variables['codeSyntax']
        @style  = @deplate.variables['codeStyle']
    end

    def process
        process_etc
        text = @elt.join("\n")
        if (s = @args['syntax'])
            @syntax = s
        end
        if (s = @args['style'])
            @style = s
        end
        if @style
            @style = Deplate::Core.clean_name(@style)
            @deplate.call_methods_matching(@deplate.formatter, /^hook_code_process_/, @style)
        end
        if @syntax
            e = nil
            fmt_name = @deplate.formatter.formatter_name
            @deplate.in_working_dir do
                id       = @args['id']
                if id
                    id.gsub!(/\W/, '00')
                    fcode    = @deplate.auxiliary_filename("code_#{id}")
                    fout     = @deplate.auxiliary_filename("code_#{id}.#{fmt_name}")
                else
                    log('No ID given', :anyway)
                    @@code_idx += 1
                    fcode = @deplate.auxiliary_filename(@deplate.auxiliary_auto_filename('code', @@code_idx, @elt, @syntax))
                    fout  = @deplate.auxiliary_filename(@deplate.auxiliary_auto_filename('code', @@code_idx, @elt, fmt_name))
                end

                # highlighter_agent = nil
                # specialized_highlighter = self.class.syntax_highlighter[@syntax]
                # if specialized_highlighter
                #     specialized_highlighter.each do |fmt, agent|
                #         if @deplate.formatter.matches?(fmt)
                #             highlighter_agent = agent
                #             break
                #         end
                #     end
                # end
                # unless highlighter_agent
                #     highlighter_agent = self.class.general_highlighter[fmt_name]
                # end
                # unless highlighter_agent
                #     log(['No highlighter defined', fmt_name], :error)
                #     return self
                # end

                if Deplate::Region.check_file(self, fout, fcode, @elt)
                    log(["Files exist! Using", fout], :anyway)
                    File.open(fout) {|io| @elt = io.readlines.collect {|l| l.chomp}}
                    return self
                else
                    highlighter_agent = nil
                    begin
                        specialized_highlighter = self.class.syntax_highlighter[@syntax]
                        if specialized_highlighter
                            specialized_highlighter.each do |fmt, agent|
                                if @deplate.formatter.matches?(fmt)
                                    highlighter_agent = agent
                                    e = send(agent, @syntax, @style, text)
                                    # p "DBG Code 1 #{e.class}"
                                    break if e
                                end
                            end
                        end
                        unless e
                            highlighter_agent = agent = self.class.general_highlighter[fmt_name]
                            e     = send(agent, @syntax, @style, text) if agent
                            # p "DBG Code 2 #{e.class}"
                        end
                    rescue StandardError => err
                        log("#Code: #{err}", :error)
                    end
                    # p "DBG", highlighter_agent, self.class.options[highlighter_agent], self.class.options[highlighter_agent][:no_cache]
                    if e and !self.class.options[highlighter_agent][:no_cache]
                        File.open(fcode, "w") {|io| io.puts(text)} if fcode
                        File.open(fout, "w")  {|io| io.puts(e)}  if fout
                    end
                end
            end
            if e
                case e
                when Array
                    @elt = e
                when String
                    p "DBG e should be an Array. Please report."
                    @elt = e.split("\n")
                else
                    raise "DBG Unknown class for e: #{e.class}. Please report."
                end
                return self
            end
        else
            log("Code: No syntax defined!", :error)
        end
        return Deplate::Regions::Verbatim.new(@deplate, @source, @elt, @match, self).finish.process
    end
end


class Deplate::Regions::Inlatex < Deplate::Region
    register_as 'Inlatex'
    register_as 'Ltx'
    register_as 'Latex'
    register_as 'LaTeX'
    set_formatter :format_inlatex
    self.label_mode = :once

    attr_reader :content_type

    def setup(region)
        super
        @content_type = @args["type"] || "fig"
    end

    def finish
        finish_accum
        pre = @deplate.variables['inlatexPrelude']
        @accum = [pre, @accum].flatten.compact if pre
        @deplate.formatter.inlatex(self)
        return self
    end

    def process
        process_etc
        return self
    end

    def register_caption
        if @args["inline"]
            log("Cannot attach caption to a LaTeX fragment marked as inline", :error)
        elsif @content_type == "table"
            register_table
        elsif @content_type == "fig"
            register_figure
        end
    end
end


class Deplate::Regions::Img < Deplate::Region
    register_as 'Img'
    register_as 'Image'
    register_as 'Fig'
    register_as 'Figure'

    @@ImgAutoN   = 0
    @@ImgSuffix  = {}
    
    def finish
        finish_accum
        nt = (@args['cmd'] || (!@regNote.empty? && @regNote) || @deplate.variables['imgCmd'] || '').split(/ /)
        @prg = nt[0]
        @cmdLineArgs = nt[1..-1]
        unless @prg
            log("No programm name given!", :error)
        else
            begin
                @args["sfx"] ||= @deplate.variables["imgSfx"]
                imgClass = Deplate::Regions.const_get("Img_" + @prg)
                self.extend(imgClass)
                i = img
                i.args.update(@args)
                i.update_args
                return i
            rescue StandardError => e
                log(["Program call failed", e, e.backtrace[0..10]], :error)
            end
        end
        return nil
    end

    def img
        formatter_handler = "img_#@prg"
        if @deplate.formatter.respond_to?(formatter_handler)

            rv = Deplate::Element::PseudoElement.new(@deplate, @source, self) do |invoker|
                @deplate.formatter.send(formatter_handler, self, @accum)
            end

            class << rv
                def register_caption
                    @container.register_caption
                end

                def set_caption(*args)
                    @container.set_caption(*args)
                end
            end

        else

            id  = @args["id"]
            unless id
                @@ImgAutoN += 1
                id = @deplate.auxiliary_auto_filename('img', @@ImgAutoN, @accum)
            end
            sfx = @args["sfx"] || suffix
            src = "#{id}.#{@prg}"
            out = "#{id}.#{sfx}"
            pwd = Dir.pwd
            d   = @deplate.dest ? File.dirname(@deplate.dest) : "."
            rv  = nil
            @deplate.in_working_dir do
                accum = prepare(@accum, out, sfx)
                if Deplate::Region.check_file(self, out, src, accum)
                    log(["Files exist! Using", out], :anyway)
                else
                    unless @deplate.options.force
                        for f in [src]
                            if File.exist?(f)
                                raise "Please delete '#{f}' or change the id before proceeding"
                            end
                        end
                    end
                    Deplate::External.write_file(self, src) {|io| io.puts(accum.join("\n"))}
                    run(src, out, sfx)
                end
                if block_given?
                    rv = yield(id, out)
                else
                    rv = Deplate::Command::IMG.new(@deplate, @source, out, @match, @args, "IMG")
                    rv.finish
                end
            end
        end
        return rv

    end

    def suffix
        block = @@ImgSuffix[@deplate.formatter.class]
        if block
            return block.call(self)
        else
            return "png"
        end
    end

end


module Deplate::Regions::Img_standard
    def prepare(accum, out, sfx)
        return accum
    end

    def run(dot, out, sfx)
        raise "SubClassResponsibility"
    end
end

module Deplate::Regions::Img_dot
    include Deplate::Regions::Img_standard

    def run(dot, out, sfx)
        Deplate::External.dot(self, sfx, dot, out, @cmdLineArgs)
    end
end

module Deplate::Regions::Img_neato
    include Deplate::Regions::Img_standard

    def run(dot, out, sfx)
        Deplate::External.dot(self, sfx, dot, out, @cmdLineArgs)
    end
end

module Deplate::Regions::Img_R
    include Deplate::Regions::Img_standard

    def prepare(accum, out, sfx)
        pre  = []
        post = []

        # trellis.device(jpeg, file="plotTrouble2.jpg",
        # theme = col.whitebg(),height=480,width=480)
        # trellis.last.object()
        # dev.off() 
        case sfx
        when "png"
            args = check_arguments("png", ["width", "height", "pointsize", 
                                   "bg"])
            pre << %{png(filename="#{out}"%s)} % args
        when "jpg"
            args = check_arguments("png", ["width", "height", "pointsize", 
                                   "bg", "pointsize", "quality", "res"])
            pre << %{jpg(filename="#{out}"%s)} % args
        when "bmp"
            args = check_arguments("png", ["width", "height", "pointsize", 
                                   "bg", "pointsize", "res"])
            pre << %{bmp(filename="#{out}"%s)} % args
        when "pdf"
            args = check_arguments("pdf", ["width", "height", "family", 
                                   "title", "encoding", "bg", "fg", 
                                   "pointsize"])
            pre << %{pdf(file="#{out}", onefile=TRUE%s)} % args
        when "ps"
            args = check_arguments("ps", ["width", "height", "family", 
                                   "title", "encoding", "bg", "fg", 
                                   "pointsize", "horizontal"])
            pre << %{postscript(file="#{out}", onefile=TRUE, paper="special"%s)} % args
        when "wmf"
            args = check_arguments("wmf", ["width", "height", "pointsize"])
            pre << %{win.metafile(filename="#{out}"%s)} % args
        else
            log(["Unknown suffix", sfx], :error)
            raise
        end
        post << "dev.off()"
        post << "q(runLast=FALSE)"
        return (pre + accum + post).flatten
    end

    def check_arguments(type, arr)
        rv = []
        for a in arr
            v = @args["%s_%s" % [type, a]] || @args["_%s" % a]
            rv << "%s=%s" % [a, v] if v
        end
        if rv.empty?
            return nil
        else
            rv.unshift(nil)
            return rv.join(", ")
        end
    end

    def run(r, out, sfx)
        Deplate::Regions::R.run(self, r, nil)
    end
end


class Deplate::Regions::Footnote < Deplate::Region::SecondOrder
# class Deplate::Regions::Footnote < Deplate::Region
    register_as 'Footnote'
    register_as 'Fn'
    self.label_mode = :none

    attr_accessor :fn_label, :fn_n, :fn_consumed

    def finish
        rv = super
        @prototype = Deplate::Element
        id = deprecated_regnote('id')
        if id
            @deplate.footnotes[id] = rv
            # @deplate.register_metadata(src, 
            #                            "type"  => "footnote", 
            #                            "name"  => id,
            #                            "value" => accum
            #                           )
        else
            log('Missing arguments', :error)
        end
        return nil
    end
end


class Deplate::Regions::Foreach < Deplate::Region
    register_as 'Foreach'
    register_as 'For'
    self.label_mode = :once

    def finish
        finish_accum
        @id = Deplate::Core.split_list(@args['@id'], ',', '; ', @source)
        unless @id
            log('No ID given', :error)
            return nil
        end
        doc = @args['var'] || @args['doc']
        if doc
            @list = @deplate.variables[doc]
        else
            @list = deprecated_regnote('each')
        end
        case @list
        when nil
            log('Missing arguments', :error)
            return nil
        when Array
            @list = @list.flatten
        else
            rx = @args['rx']
            if rx
                @list = @list.split(Regexp.new(rx))
            else
                sep = @args['sep']
                if sep
                    sep = Regexp.new(Regexp.escape(sep))
                    @list = @list.split(sep)
                else
                    @list = [@list]
                end
            end
        end
        use_template = !(@args['noTemplate'] || deplate.variables['legacyFor1'])
        if use_template
            tmpl = Deplate::Template.new(:master    => @deplate,
                                         :template  => @accum,
                                         :source    => @source,
                                         :container => self)
        end
        @foreach = []
        while !@list.empty?
            ids = {}
            for i in @id
                ids[i] = @list.shift
            end
            Deplate::Define.let_variables(@deplate, ids) do
                if use_template
                    body = tmpl.fill_in(deplate, :source => @source)
                else
                    body = @accum
                end
                acc  = @deplate.parsed_array_from_strings(body, 1 + @source.begin, @source.file)
                @prototype ||= acc[0]
                @foreach << [ids, acc]
            end
        end
        return self
    end

    def process_particles(&block)
        @elt = []
        for ids, acc in @foreach
            Deplate::Define.let_variables(@deplate, ids) do
                @elt << acc.collect {|e| e.process}
            end
        end
        @elt = @elt.flatten.compact
    end

    alias format_special format_compound
end


class Deplate::Regions::Table < Deplate::Region
    register_as 'Table'
    
    def finish
        finish_accum
        case @regNote.strip
        when "limited"
            log("Not yet implemented!", :error)
            return nil
        else
            return Deplate::Regions::Table.make_char_separated(self, @accum, @args["sep"])
        end
    end

    # duck method
    def register_caption
    end

    class << self
        def make_char_separated(instance, accum, sep=nil)
            sep   = Regexp.new(sep || "\t")
            acc   = accum.collect {|l| %{| #{l.gsub(sep, " | ")} |}}
            beg   = 1 + instance.source.begin
            file  = instance.source.file
            table = instance.deplate.parsed_array_from_strings(acc, beg, file)
            n     = table[0]
            n.collapse = false
            n.unify_props(instance)
            return n
        end
    end
end


class Deplate::Regions::Verbatim < Deplate::Region
    register_as 'Verbatim'
    register_as 'Verb'
    set_formatter :format_verbatim
    set_line_cont false
    class_attribute :indentation_mode, :none

    def finish
        finish_accum
        @elt = [ @accum ]
        @verbatimMargin = @deplate.variables['verbatimMargin']
        return self
    end

    def process
        process_etc
        @elt = @elt.join("\n")
        if @args['removeBackslashes']
            @elt = Deplate::Core.remove_backslashes(@elt)
        end
        margin = @args['wrap'] || @verbatimMargin
        if margin
            @elt = @deplate.formatter.wrap_text(@elt, :margin => margin.to_i)
        end
        # @elt = Deplate::Core.remove_backslashes(@elt.join("\n"))
        return self
    end
end


class Deplate::Regions::Abstract < Deplate::Region::SecondOrder
    register_as 'Abstract'
    set_formatter :format_abstract, true

    def finish
        rv   = super
        lang = @args['lang'] || @deplate.options.lang
        hd   = @deplate.headings[@level_heading]
        if hd
            hd.abstract = self
            if hd != @top_heading
                @top_heading.abstract ||= self
            end
        else
            @deplate.register_metadata(@source, 
                                       'type'  => 'abstract', 
                                       'lang'  => lang,
                                       'value' => @accum
                                      )
        end
        rv
    end
end


# class Deplate::Regions::Quote < Deplate::Region
class Deplate::Regions::Quote < Deplate::Region::SecondOrder
    register_as 'Quote'
    register_as 'Qu'
    set_formatter :format_quote, true
end


class Deplate::Regions::Region < Deplate::Region::SecondOrder
    register_as 'Region'
    register_as 'Block'
    set_formatter :format_region, true
end


class Deplate::Regions::R < Deplate::Region
    register_as 'R'

    @@RAutoN   = 0

    def finish
        finish_accum
        if @deplate.formatter.respond_to?(:region_R)
            return Deplate::Element::PseudoElement.new(@deplate, @source, self) do |invoker|
                @deplate.formatter.send(:region_R, self, @accum)
            end
        else
            begin
                return do_R
            rescue StandardError => e
                log(["Program call failed", e, e.backtrace[0..10]], :error)
                return nil
            end
        end
    end

    def do_R
        pre = @deplate.variables['rPrelude']
        if pre
            @accum = [pre, @accum].flatten.compact
        end
        id  = @args["id"]
        unless id
            @@RAutoN += 1
            id = @deplate.auxiliary_auto_filename('r', @@RAutoN, @accum)
        end
        r   = "#{id}.R"
        out = "#{id}.Rout"
        case @regNote.strip
        when "xtable"
            rOut = do_xtable(r, out)
        when "drop", "swallow"
            rOut = do_drop(r, out)
        when "verb", "verbatim"
            rOut = do_verbatim(r, out)
        else
            rOut = do_normal(r, out)
        end
        if rOut
            rOut.args.update(@args)
            return rOut
        end
    end

    def do_xtable(r, out)
        @accum.unshift(%{library(xtable)})
        if send_to_R(r, out)
            table = []
            pre   = []
            # cap   = nil
            post  = []
            mode  = :pre
            for l in @accum
                xtable_postprocess_text(l)
                m = /^\s*\<([^> ]+).*?\>(.*)?(\<\/(\S+)\>)?\s*$/.match(l)
                if m
                    case m[1]
                    when "!--"
                        next
                    when "TABLE"
                        mode = :table
                    when "/TABLE"
                        mode = :post
                    when "TR"
                        row = l.scan(/\<TH.*?\>\s*(.*?)\s*<\/TH\>/).flatten
                        unless row.empty?
                            table << "|| #{row.join(" || ")} ||"
                        else
                            row = l.scan(/\<TD.*?\>\s*(.*?)\s*\<\/TD\>/).flatten
                            table << "| #{row.join(" | ")} |" unless row.empty?
                        end
                        log(["R xtable: row", row], :debug)
                        # when "CAPTION"
                        # mc = /\<CAPTION.*?\> (.*) \<\/CAPTION\>$/.match(l)
                        # cap = mc[1]
                    else
                        log(["Skip", m[1]])
                    end
                else
                    case mode
                    when :pre
                        pre << l
                    when :post
                        post << l
                    end
                end
            end
            accum = @deplate.parsed_array_from_strings(table, 1 + @source.begin, @source.file)
            if accum.size != 1
                log(["Unexpected R output (too many elements)", 
                    out, accum.collect {|e| e.class}], :error)
            end
            until accum.empty? or accum[0].kind_of?(Deplate::Element::Table)
                e = accum.shift
                log(["Unexpected R output (Please check the output for errors!)",
                    out, e.class], :error)
            end
            rOut = accum[0]
            if rOut
                rOut.collapse = false
                rOut.preNote  = pre.join("\n")
                rOut.postNote = post.join("\n")
                log(["R xtable: pre", rOut.preNote],   :debug)
                log(["R xtable: post", rOut.postNote], :debug)
                return rOut
            end
        end
    end

    def do_drop(r, out)
        send_to_R(r, out)
        return nil
    end

    def do_verbatim(r, out)
        if send_to_R(r, out)
            @elt = @accum.join("\n")
            rOut = Deplate::Regions::Verbatim.new(@deplate, @source, @text, @match, self)
            rOut.finish
            return rOut
        end
    end

    def do_normal(r, out)
        if send_to_R(r, out)
            scn = table_scanner(@accum)
            @accum.collect! do |r|
                if r =~ /^\s*$/
                    "|   |"
                elsif @args['guess'] or @args['scanTable'] or @deplate.variables['rScanTable']
                    cells = scn.match(r)
                    if cells
                        cells = cells.captures.collect do |c|
                            v = c.strip
                            v.empty? ? @deplate.formatter.table_empty_cell : v
                        end
                        ['|', cells.join(' | '), '|'].join(' ')
                    else
                        puts @accum.join("\n")
                        raise 'DBG: Error in table scanner (please report)'
                    end
                else
                    "| %s |" % Deplate::Particle::Code.markup(r.gsub(/ /, "\\\\ "))
                end
            end
            accum = @deplate.parsed_array_from_strings(@accum, 1 + @source.begin, @source.file)
            # if accum.size != 1 and accum[0].class != Deplate::Element::Table
            if accum[0].class != Deplate::Element::Table
                log(["Expected exactly one element of type Table", accum.collect {|e| e.class}.join(" ")], :error)
            end
            rOut = accum[0]
            if rOut
                rOut.collapse = false
            else
                log(["R yielded no output", out], :error)
            end
            return rOut
        end
    end
    
    def table_scanner(strings)
        max = 0
        for l in strings
            ls = l.size
            if ls > max
                max = ls
            end
        end
        blanks = [true] * max
        for l in strings
            for i in 0..(l.size - 1)
                if l[i] != 32
                    blanks[i] &&= false
                end
            end
        end
        lst = true
        blanks.collect! do |c|
            if c and lst
                rv = false
            else
                rv = c
            end
            lst = c
            rv
        end
        acc = []
        lst = -1
        blanks.each_with_index do |c, i|
            if c
                d   = i - lst
                lst = i
                acc << ' ' unless acc.empty?
                acc << '(' << '.' * (d - 1) << ')'
            end
        end
        d = max - 1 - lst
        if d > 1
            acc << ' ' unless acc.empty?
            acc << '(' << '.' * (d - 1) << ')'
        end
        Regexp.new(acc.join)
    end
    
    def xtable_postprocess_text(text)
        text.gsub!(/&amp;?/,  %{&})
        text.gsub!(/&lt;?/,   %{<})
        text.gsub!(/&gt;?/,   %{>})
        text.gsub!(/&quot;?/, %{"})
        text
    end

    def send_to_R(r, out)
        pwd = Dir.pwd
        d   = File.dirname(@deplate.dest)
        rv  = false
        @deplate.in_working_dir do
            log(["Running R", d, r, out])
            begin
                @accum.unshift(%{deplate.fmt <- "#{@deplate.formatter.formatter_name}"})
                @accum << %{q(runLast=FALSE)}
                if Deplate::Region.check_file(self, out, r, @accum)
                    log(["Files exist! Using", out], :anyway)
                else
                    unless @deplate.options.force
                        for f in [r, out]
                            if File.exist?(f)
                                raise "Please delete '#{f}' or change the id before proceeding\nUse the --force option to avoid this message."
                            end
                        end
                    end
                    Deplate::External.write_file(self, r) {|io| io.puts(@accum.join("\n"))}
                    run(r, out)
                end
                @accum = File.open(out) {|io| io.read}.split(/[\n\r]+/)
                skip = @args["skip"]
                if skip
                    head, tail = Deplate::Core.split_list(skip, nil, nil, @source).collect {|n| n.to_i}
                    @accum = @accum[(head || 0) .. (@accum.size - tail - 1 || -1)] || []
                end
                rv = true
            rescue StandardError => e
                log("#R: #{e}", :error)
            end
        end
        return rv
    end

    def run(r, out)
        return Deplate::Regions::R.run(self, r, out)
    end

    class << self
        def run(container, r, out)
            Deplate::External.r(container, r, out)
        end
    end
end


class Deplate::Regions::Ruby < Deplate::Region
    register_as 'Ruby'

    def finish
        finish_accum
        @accum = [@deplate.eval_ruby(self, @args, @accum.join("\n")).to_s]
        if @args['verb']
            return Deplate::Regions::Verbatim.new(@deplate, @source, @accum, @match, self).finish
        elsif @args['img'] or @args['image']
            file = @args['img'] || @args['image']
            return Deplate::Command::IMG.new(@deplate, @source, file, nil, {}, 'IMG').finish
        elsif @args['native']
            return Deplate::Regions::Native.new(@deplate, @source, @accum, @match, self).finish
        else
            acc = []
            @accum.collect! {|l| l.split(/\n/)}
            @accum.flatten!
            @deplate.include_stringarray(@accum, acc, @source.begin, @source.file)
            return acc
        end
    end
end


class Deplate::Regions::Clip < Deplate::Region::SecondOrder
    register_as 'Clip'
    register_as 'Put'
    register_as 'Set'

    # attr_accessor :prototype
    attr_reader :is_template, :inline

    def from_strings(strings)
        @accum = strings
        finish
    end

    def finish
        finish_accum
        id           = deprecated_regnote('id')
        @doc_type    = :array
        @processed   = false
        @elt         = @deplate.parsed_array_from_strings(@accum, @source.begin, @source.file)
        @deplate.set_clip(id, self)
        return nil
    end

    def process
        unless @processed
            @processed = true
            return super
        else
            return self
        end
    end

    def format_clip(invoker, expected)
        @expected = expected
        @invoker  = invoker
        format_special
    end

    def log(*args)
        if defined?(@invoker) and @invoker
            @invoker.log(*args)
        else
            super
        end
    end
end


class Deplate::Regions::Header < Deplate::Region
    register_as 'Header'
    set_formatter :format_header
    
    def finish
        finish_accum
        @elt = @deplate.parsed_array_from_strings(@accum, 1 + @source.begin, @source.file)
        return self
    end

    def process
        process_etc
        for e in @elt
            e.process
        end
        @elt.compact!
        return self
    end
end


class Deplate::Regions::Footer < Deplate::Regions::Header
    register_as 'Footer'
    set_formatter :format_footer
end


class Deplate::Regions::Swallow < Deplate::Region
    register_as 'Swallow'
    register_as 'Skip'
    register_as 'Drop'

    def finish
        finish_accum
        @elt = @deplate.parsed_array_from_strings(@accum, 1 + @source.begin, @source.file)
        return self
    end

    def process
        process_etc
        for e in @elt
            e.process
        end
        return nil
    end
end

