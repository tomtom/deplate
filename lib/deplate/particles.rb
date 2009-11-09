# encoding: ASCII
# particles.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     24-Mär-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.1948

require "uri"
require "deplate/common"


# Sub-line level text bits.
class Deplate::Particle < Deplate::BaseParticle
    # An array of the default particle classes.
    @@particles    = []
    # The regular expression for the default particle classes.
    @@rx           = nil
    # Programmatically created particle classes, e.g., indexes, 
    # autoindexes etc.
    @@particles_extended = []
    # The rx for @@particles_extended.
    @@rx_extended        = nil

    class << self
        def particles
            @@particles
        end
        
        def rx_particles
            @@rx
        end

        def particles_ext
            @@particles_extended
        end
        
        def rx_particles_ext
            @@rx_extended
        end
        
        def match(text)
            return self.rx.match(text)
        end

        def register_particle(c=self)
            @@particles << c
        end

        def replace_particle(other, c=self)
            i = @@particles.index(other)
            if i
                @@particles[i] = c
            else
                register_particle c
            end
        end

        def disable_particle(*particles)
            particles.each {|p| @@particles.delete(p)}
        end
        
        # Create an auto-indexed word. Arguments:
        # deplate:: An instance of Deplate::Core.
        # idx:: An instance of the Deplate::IndexEntry structure.
        def auto_indexing(deplate, idx)
            if idx
                i = idx.name
                w = idx.synonymes
                name = i.gsub(/\W\|s/) do |x|
                    x.unpack('H2' * x.size)
                end
                autoindexed = deplate.options.autoindexed
                if !w.any? {|x| autoindexed.include?(x)}
                    autoindexed.concat(w)
                    aname = %{AutoIndex#{name}}
                    if self == Deplate::HyperLink
                        rx = Regexp.escape(i).gsub(/\\/, "\\\\")
                        rx.gsub!(/"/, %{\\\\"})
                        body = <<-EOR
                            set_rx(%r{^\\b#{rx}\\b})
                            def setup
                                super
                                name = match[0]
                                @elt = [@name, @dest, @anchor]
                                @idx = [deplate.add_index(self, @name)]
                                @deplate.register_metadata(@source,
                                                           'type'  => 'index',
                                                           'name'  => @name,
                                                           'label' => @idx.label,
                                                          )
                            end
                        EOR
                    else
                        idxName = Regexp.escape(i)
                        rx      = w.collect {|i| Regexp.escape(i)}.join("\\b|\\b")
                        rx.gsub!(/"/, %{\\\\"})
                        body = <<-EOR
                            set_rx(%r{^\\b#{rx}\\b})
                            def setup
                                @idx = @deplate.add_index(self, %{#{idxName}}) if @container
                            end
                            def process
                                if @container
                                    @elt = plain_text(Deplate::Core.remove_backslashes(@match[0])) + 
                                        format_particle(:format_index, self, @idx)
                                else
                                    @elt = ''
                                end
                            end
                        EOR
                    end
                    cls = Deplate::Cache.particle(deplate, body, 
                                                  :super    => Deplate::Autoindex,
                                                  :register => true,
                                                  :extended => true)
                end
            end
        end

        def insert_particle_before(klass)
            idx = @@particles.index(klass) || -1
            @@particles.insert(idx, self)
        end
    
    end

    def initialize(deplate, container, context, match, alt, last='', rest='', args={})
        super(deplate, :container => container)
        self.level_as_string = container.level_as_string if container
        @context   = context
        @match     = match
        @last      = last
        @rest      = rest
        @alt       = alt
        @args      = args
        setup
    end

    def setup
    end

    def process
    end
end


class Deplate::Autoindex < Deplate::Particle
end


# A wrapper class for simple particles that require only minimal 
# processing.
class Deplate::SimpleParticle < Deplate::Particle
    def setup
        @elt = @deplate.parse(@container, get_text, @alt)
    end
    
    def get_text
        @match[1]
    end
    
    def process
        @elt = @deplate.format_particles(@elt)
        fmt  = self.class.formatter
        if fmt
            @elt = format_particle(fmt, self, @elt)
        # else
        #     raise 'Internal error: No formatter'
        end
    end
end


# A pseudo-particle class. Note the following difference: @match holds 
# the plain text as String and not as MatchData.
class Deplate::Particle::Text < Deplate::Particle
    # set_formatter :plain_text
    class << self
        def pseudo_match(text)
            [text]
        end
    end

    def process
        if @args[:raw]
            @elt = get_text
        else
            @elt = plain_text(get_text)
        end
    end

    def get_text
        @match[0]
    end
end


# Match characters escaped with a backslash.
class Deplate::Particle::Escaped < Deplate::Particle
    register_particle
    set_rx(/^\\(.)/)
    def process
        @elt = plain_text(@match[1], true)
    end
end


# Match emphasized text marked as <tt>__text__</tt>.
class Deplate::Particle::Emphasize < Deplate::SimpleParticle
    class << self
        def markup(text)
            if text
                [
                    '__', 
                    Deplate::Core.escape_characters(text, :escape => '_\\'), 
                    '__'
                ].join
            end
        end
    end
    register_particle
    set_rx(/^__((\\_|.)+?)__/)
    set_formatter :format_emphasize
    # def process
    #     @elt = @deplate.format_particles(@elt)
    #     @elt = format_particle(:format_emphasize, self, @elt)
    # end
end


# Match code marked as <tt>''text''</tt> (two single quotes).
class Deplate::Particle::Code < Deplate::Particle
    register_particle
    set_rx(/^''((\\\\|\\'|.)+?)''/)
    def_get :text, 1

    class << self
        # Programmatically markup text as code. Used e.g. for some 
        # R-generated tables.
        def markup(text)
            [
                %{''}, 
                # text.gsub("'", "\\\\'"), 
                Deplate::Core.escape_characters(text, :escape => "'\\"),
                %{''}
            ].join
        end
    end
    
    def hook_pre_process
        @elt = Deplate::Core.remove_backslashes(@elt)
    end
    
    def process
        text = Deplate::Core.remove_backslashes(get_text)
        @elt = format_particle(:format_code, self, text)
    end
end


# Symbols: <-, ->, <=, =>, <~, ~>, <->, <=>, <~>, !=, ~~, ..., --, ==
# Markers: +++, ###, ???, !!!
class Deplate::Particle::Symbol < Deplate::Particle
    register_particle
    
    # An association array of symbols and method names for formatting this symbol.
    @@symbols_table = [
        ["<->"],
        ["<-" ],
        ["->" ],
        ["<=>"],
        ["<=" ],
        ["=>" ],
        ["<~>"],
        ["<~" ],
        ["~>" ],
        ["!=" ],
        ["~~" ],
        ["..."],
        ["--" ],
        ["==" ],
        ["+++"],
        ["###"],
        ["???"],
        ["!!!"],
        [">>>"],
        ["<<<"],
        ["```", :doublequote_open],
        ["`''", :doublequote_close],
        ["``",  :singlequote_open],
        ["`'",  :singlequote_close],
    ]
    # An array of symbols in order as they were defined -- as ruby 
    # eagerly sorts the keys in the @@symbols_table hash. This is used 
    # for building the rx.
    @@symbols_keys  = []

    class << self
        # Add a symbol. If val is nil, a general formatter dependent 
        # routine will be used.
        def add_symbol(key, val=nil)
            @@symbols_keys << Regexp.escape(key)
            # @@symbols_table[key] = val
        end

        # Build the rx based on @@symbols_keys.
        def setup_rx
            set_rx(Regexp.new(%{^(%s)} % @@symbols_keys.join("|")))
        end

        def reset_symbols
            @@symbols_keys = []
            for i in @@symbols_table
                add_symbol(*i)
            end
            setup_rx
        end
    end

    reset_symbols
    
    def process
        sym = @@symbols_table.assoc(@match[1])[1]
        case sym
        when ::Proc
            @elt = instance_eval(&sym)
        when ::Symbol
            @elt = @deplate.formatter.send(sym, self)
        when ::String
            @elt = format_particle(:format_symbol, self, sym)
        else
            @elt = format_particle(:format_symbol, self, @match[1])
        end
    end
end


class Deplate::Particle::DoubleQuote < Deplate::Particle
    register_particle
    set_rx(/^"/)
    def process
        if @last =~ /(^|[\s({\[])$/ or (@rest =~ /^\w/ and @last =~ /\W$/)
            @elt = format_particle(:doublequote_open, self)
        else
            @elt = format_particle(:doublequote_close, self)
        end
    end
end


class Deplate::Particle::SingleQuote < Deplate::Particle
    register_particle
    set_rx(/^'/)
    def process
        if @last =~ /(^|[\s({\[])$/ or (@rest =~ /^\w/ and @last =~ /\W$/)
            @elt = format_particle(:singlequote_open, self)
        else
            @elt = format_particle(:singlequote_close, self)
        end
    end
end


# Define interwikis.
module Deplate::InterWiki
    @@interwikis = {}
    Deplate::InterWikiDef = Struct.new("DeplateInterWikiDef", :id, :url, :sfx)
    class << self
        # Add an interwiki definition. E.g.:
        #   Deplate::InterWiki.add("DEPLATE", "http://deplate.sf.net/", ".html")
        def add(id, *args)
            @@interwikis[id] = Deplate::InterWikiDef.new(id, *args)
        end
    end
end


# This class is meant to be subclassed.
#
# The class variables @@uc (upper case letters) and @@lc (lower case 
# letters) define the set of characters allowed in wiki names.  
# International users might want to change the default value in their 
# config.rb file.
class Deplate::HyperLink < Deplate::Particle
    # @@uc = "A-Z"
    # @@lc = "a-z"

    # Upper case letters in wiki names.
    @@uc = '[:upper:]'
    # Lower case letters in wiki names.
    @@lc = '[:lower:]'

    # The name of the interwiki, if any.
    # attr :inter

    class << self
        # Call this method after changing the markup for hyperlinks, e.g., 
        # by changing the set of allowed characters in wiki names.
        def setup(upper=nil, lower=nil)
            @@uc = upper if upper
            @@lc = lower if lower
            @@ac = "[#{@@uc}#{@@lc}][#{@@uc}#{@@lc}_0-9]+"
            @@bc = "[#{@@uc}#{@@lc}_0-9-][#{@@uc}#{@@lc}_0-9-]+"
            Deplate::HyperLink::Extended.setup
            Deplate::HyperLink::Simple.setup
        end

        # Concatenate url and anchor, if any.
        def url_anchor(url, anchor)
            dest = [url]
            if anchor and !anchor.empty?
                dest << '#' << anchor
            end
            dest.join
        end

        def upper_case_chars
            @@uc
        end

        def lower_case_chars
            @@lc
        end
        
        def chars
            @@uc + @@lc
        end
    end
    
    include Deplate::InterWiki

    def get_InterWiki(id)
        d = @@interwikis[id]
        Deplate::Core.log(['Unknown InterWiki name', id], :error, @container.source) unless d
        return d
    end
   
    def guess_label(dest, anchor)
        src   = @container.source.file
        dest  = File.expand_path(dest, src ? File.dirname(src) : nil)
        label = anchor || @deplate.file_label(dest)
        # return @deplate.labels[label]
        return label
    end
    
    # guess if a wiki name refers to the file at hand (or its included files) or 
    # if it's an external reference/URL.
    # 
    # +++ the heuristic is fragile and sometimes gives wrong results
    def complete_wiki_ref(inter, name, dest, anchor)
        src = @container.source.file || ''
        sfx = @deplate.variables['suffix']
        if sfx
            sfx = '.%s' % sfx
        elsif @deplate.variables['useParentSuffix']
            sfx = File.extname(src)
        end
        if dest.empty?
            label = guess_label(dest, anchor)
            if label
                dest = @container.output_file_name(:relative => self)
                return :wiki, name, dest, label
            else
                log(['Wiki reference to unknown anchor', "#{dest}##{anchor}"], :error)
                return nil
            end
        elsif @literal
            return :url, name, dest, anchor
        elsif dest =~ /^#/
        # does it "resemble" an url?
        elsif dest =~ Deplate::HyperLink::Url.rx
        # elsif dest =~ URI::REGEXP::ABS_URI
            if !name or name.empty?
                name = dest
            end
            return :url, name, dest, anchor
        # if its an interwiki name, we rely on the interwiki definition, if 
        # provided
        elsif inter
            d = get_InterWiki(inter)
            if d
                return :url, name, d.url + @deplate.file_with_suffix(dest, d.sfx), anchor
            end
        # we then check if the file was included
        elsif @deplate.file_included?(dest, File.dirname(@container.source.file || ''), sfx)
            label = guess_label(@deplate.file_with_suffix(dest, sfx), anchor)
            if label
                dest = @container.output_file_name(:label => label)
            else
                dest = ''
            end
            return :wiki, name, dest, label
        end
        # Fallback heuristic
        dest_sfx = File.extname(dest)
        dest_abs = File.expand_path(dest, File.basename(src))
        dest_is_dir = (File.exist?(dest_abs) and File.stat(dest_abs).directory?)
        if !dest_is_dir and (dest_sfx == '' or dest_sfx == sfx or dest_sfx == File.extname(src))
            dest1 = @deplate.file_with_suffix(dest, @deplate.options.suffix)
            name  = dest1 if !dest_sfx.empty? and (name == dest or name == '')
            return :url, name, dest1, anchor
        else
            return :url, name, dest, anchor
        end
    end

    def indexing(idx)
        idx = idx.compact
        unless @deplate.variables['indexwiki'] == 'no' or idx.empty?
            if @deplate.variables['autoindex']
                for i in idx
                    Deplate::Particle.auto_indexing(@deplate, i)
                end
            end
            @idx = idx
        else
            @idx = nil
        end
    end
   
    def process
        type, name, dest, anchor = complete_wiki_ref(@inter, *@elt)
        if type
            dest.gsub!(/\\/, '/')
            dest   = encode_dest(dest)
            anchor = encode_anchor(anchor)
            set_style(dest)
            case type
            when :wiki
                @elt = format_particle(:format_wiki, self, name, dest, anchor)
            when :url
                @elt = format_particle(:format_url, self, name, dest, anchor)
            end
            # p "DBG", dest, type, @styles, @elt
            if @idx
                @idx.collect! do |idx|
                    format_particle(:format_index, self, idx)
                end
                @elt += @idx.join 
            end
        end
    end

    protected
    def set_style(dest)
        if dest =~ Deplate::HyperLink::Url.rx
            if dest =~ /^mailto:/
                @styles << 'mailto'
            else
                @styles << 'remote'
            end
        end
    end

    # Escape special characters from path
    def encode_path(path)
        path = path.split(Regexp.new(Regexp.escape(File::SEPARATOR)))
        hd   = path[0] =~ /^[a-zA-Z][:|]$/ ? path.shift : nil
        path = [hd, path.collect {|p| URI.escape(p)}].compact
        File.join(*path)
    end

    def encode_dest(dest)
        if dest =~ /^~/
            return 'file://%s' % File.join(ENV['HOME'], encode_path(dest[1..-1]))
        elsif dest =~ Deplate::HyperLink::Url.rx
        # elsif dest =~ URI::REGEXP::ABS_URI
            # if it looks like an url, we assume that it's already properly encoded
            # or should we do some checks?
            # <+TBD+>
            return dest
        else
            return encode_path(dest)
            # dest = ["file://" + File.expand_path(dest)]
        end
    end

    def encode_anchor(anchor)
        URI.escape(anchor) if anchor
    end
end


# Match extended wiki names:
#   [[destination]]
#   [[destination][name]]
#   [[destination#anchor][name]]
#   [[#anchor]]
#   [[#anchor][name]]
class Deplate::HyperLink::Extended < Deplate::HyperLink
    register_particle

    class << self
        def setup
            # @rx  = /^\[\[([^\]#]*)(#(#{@@bc}))?\](\[(.+?)\])?([-!~*]*)\]/
            # @rx  = /^\[\[([^\]#]*)(#([^\]]*))?\](\[(.+?)\])?([-!~*]*)\]/
            set_rx(/^\[\[(([#{@@uc}]+?)::)?([^\]#]*)(#([^\]]*))?\](\[(.+?)\])?([-!~*$]*)\]/)
        end
    end
    
    def_get :interwiki, 2
    def_get :destination, 3
    def_get :anchor, 5
    def_get :name, 7
    def_get :modifier, 8

    def setup
        @inter    = get_interwiki
        @dest     = get_destination || ''
        @anchor   = get_anchor
        @name     = get_name
        @modifier = get_modifier || ''
        unless @modifier.include?('-')
            if @name
                id = @name
            else
                if !@dest or @dest.empty?
                    @name = @anchor || @inter
                    id    = @anchor || @inter
                else
                    @name = @dest
                    id    = File.basename(@dest)
                end
            end
            if id
                idx = [@deplate.add_index(self, id)]
            else
                idx = []
            end
        else
            idx = []
        end
        @idx     = indexing(idx)
        @literal = @modifier.include?('!')  # || @dest =~ Deplate::HyperLink::Url.rx
        if @modifier.include?('~') and @dest =~ /^\~/
            @dest = File.expand_path(@dest)
        end
        if @modifier.include?('*')
            @args['target'] = '_blank'
        end
        if @modifier.include?('$')
            @args['rel'] = 'nofollow'
        end
    end
    
    def process
        @name = @deplate.parse_and_format(self, @name, false, :excluded => [
                                         Deplate::HyperLink::Extended,
                                         Deplate::HyperLink::Simple,
                                         Deplate::HyperLink::Url,
        ])
        @dest = @deplate.parse_and_format(self, @dest, false, :raw => true, :excluded => [
                                         Deplate::HyperLink::Extended,
                                         Deplate::HyperLink::Simple,
                                         Deplate::HyperLink::Url,
        ])
        # @name = plain_text(Deplate::Core.remove_backslashes(@name))
        @elt  = [@name, @dest, @anchor]
        super
    end
end


# Match simple wiki names.
#
# Simple Deplate Names:
#   DeplateName
#   DeplateName#anchor
# 
# Quoted Deplate Names:
#   [-name-]
#   [-some name-]#there
#
# Interdeplate:
#   OTHERDEPLATE::DeplateName
#   OTHERDEPLATE::DeplateName#there
#   OTHERDEPLATE::[-some name-]
#   OTHERDEPLATE::[-some name-]#there
class Deplate::HyperLink::Simple < Deplate::HyperLink
    register_particle
    self.pre_condition = lambda do |match|
        pre = match.pre_match
        cond = pre.empty? || pre !~ /[#{@@uc}#{@@lc}[:alnum:]]$/
        if cond
            post = match.post_match
            cond &&= (post.empty? || post !~ /^[#{@@uc}#{@@lc}[:alnum:]]/)
        end
        cond
    end

    class << self
        def setup
            # @rx = /^((\b[#{@@uc}]+)::)?(\[-(.*?)-\]|\b[#{@@uc}][#{@@lc}]+([#{@@uc}][#{@@lc}0-9]+)+\b)(#(#{@@ac})\b)?/
            # set_rx(/^(([#{@@uc}]+)::)?(\[-(.*?)-\]|\b[#{@@uc}][#{@@lc}]+([#{@@uc}][#{@@lc}0-9]+)+\b)(#(#{@@ac}))?/)
            set_rx(/^(([#{@@uc}]+)::)?(\[-(.*?)-\]|[#{@@uc}][#{@@lc}]+([#{@@uc}][#{@@lc}0-9]+)+)(#(#{@@ac}))?/)
            # @rx = /^(([#{@@uc}]+)::)?(\[-(.*?)-\]|\b[A-Z][#{@@lc}]+([#{@@uc}][#{@@lc}0-9]+)+)(#(#{@@ac}))?(?!#{@@ac})/
            # @rx = /^(([#{@@uc}]+)::)?(\[-(.*?)-\]|\b[#{@@uc}][#{@@lc}]+([#{@@uc}][#{@@lc}0-9]+)+)(#(#{@@ac}))?(?!(#{@@ac}|$))/
        end
    end

    def setup
        @inter   = get_interwiki
        @dest    = get_destination
        @anchor  = get_anchor
        @literal = nil
        if @dest.empty?
            @name = "#" + @anchor
        else
            @name = @dest
        end
        idx  = [@deplate.add_index(self, @name)]
        @idx = indexing(idx)
    end

    def get_interwiki
        @match[2]
    end

    def get_destination
        @match[4] || @match[3]
    end

    def get_anchor
        @match[7]
    end
    
    def process
        # @name = @deplate.parse_and_format(self, @name, false)
        @name = plain_text(Deplate::Core.remove_backslashes(@name))
        @elt  = [@name, @dest, @anchor]
        super
    end
end


# Match URLs.
class Deplate::HyperLink::Url < Deplate::HyperLink
    register_particle
    # We could also try to use URI::REGEXP::ABS_URI
    # @rx = /^((https?|ftps?|nntp|mailto|mailbox):([#{@@uc}#{@@lc}0-9.:%?=&_~@\/\|-]+?))(#([-#{@@uc}#{@@lc}0-9]*))?([.,;:!?)}\]]*\s|$)/
    set_rx(/^((https?|ftps?|nntp|mailto|mailbox|file):(\S+?)(#([-#{@@uc}#{@@lc}0-9]*))?)(?=[.,;:!?)}\]]+\s|\s|$)/)

    def setup
        @dest    = get_destination
        @name    = @dest
        @anchor  = get_anchor
        @literal = true
    end
   
    def get_destination
        # @match[0]
        @match[1]
    end

    def get_anchor
        # @match[4]
        m = @match[5]
        if m
            rv = m.split(/#/)[1]
            rv
        else
            nil
        end
    end
    
    def process
        @name = plain_text(@name)
        set_style(@dest)
        @elt  = format_particle(:format_url, self, @name, @dest, @anchor)
    end
end

Deplate::HyperLink.setup


# General macro reader. A macro has the form {NAME ARGS: BODY}. Curly 
# braces in the body part have to be escaped with a backslash. ARGS 
# match a series of:
# * arg!
# * noArg!
# * key=value
# * key="value"
# * key=(value)
class Deplate::Particle::Macro < Deplate::Particle
    register_particle

    # The macro name.
    attr_reader :macro
   
    set_rx Deplate::Rx.builder('\\{(?>\\\\\\{|\\\\\\}|\\\\\\\\|[^{}]+?|{#})*\\}')

    def setup
        begin
            macro = get_text
            if macro.empty?
                @elt = plain_text(@match[0], false)
            else
                @macro, args, text = split_name_args(macro)
                args = args.merge(deplate.variables["args@#{@macro}"] || {})
                # args[:macro] = macro
                if @macro
                    @elt = Deplate::Macro.exec(@deplate, @container, @context, @macro, args, @alt, text)
                    if @elt
                        @args = @elt.args
                    else
                        args[:match] = @match
                        @elt = Deplate::Macro::Unknown.new(@deplate, @container, @context, args, @alt, text)
                    end
                    @deplate.register_id(@args, @elt)
                else
                    Deplate::Core.log(["Malformed macro", @match[0]], :error, @container.source)
                end
            end
        rescue Deplate::DontFormatException
            Deplate::Core.log(["Dropping", @match[0]], nil, @container.source)
        end
    end

    def get_text
        @match[0][1..-2]
    end

    def split_name_args(macro)
        # m = /^([^a-zA-Z]|[[:alnum:]_]+)(.*)$/.match(macro)
        m = /^([^a-zA-Z]|[^:[:space:]]+)(.*)$/.match(macro)
        if m
            macro = m[1]
            if macro =~ /^[^a-zA-Z]/
                text = m[2]
                args = {}
            else
                body = m[2].gsub(/([\\{}])/, '\\\\\\1')
                args, text = @deplate.input.parse_args(m[2], @container)
            end
            [macro, args, text]
        else
            nil
        end
    end

    def process
        @elt = case @elt
               when String
                   @elt
               when nil
                   ''
               else
                   @elt.process
               end
    end
end


# Give warnings about misplaced, unbalanced, or not-escaped curly braces.
class Deplate::Particle::CurlyBrace < Deplate::Particle
    register_particle
    set_rx(/^([{}])/)

    def process
        sample_pre  = @last[-10..-1]
        sample_post = @rest[0..9]
        Deplate::Core.log(["Character should be preceded by a backslash", "%s>>%s<<%s" % [sample_pre, @match[0], sample_post]], :error, @container.source)
        @elt = plain_text(@match[0], false)
    end
end


# Match against whitespace. This class is currently only used for 
# template input filter.
class Deplate::Particle::Whitespace < Deplate::Particle
    set_rx(/^\s+/)

    def process
        @elt = @match[0]
    end
end


# This is a general word class that will some day in the future handle 
# autoidx, index, abbreviation requests.
# Currently useless.
class Deplate::Particle::Word < Deplate::Particle
    # register_particle
    set_rx(/^(`?[^[:space:][:punct:]]+)/)
    def process
        word = get_text
        @elt = plain_text(word, false)
    end
    def get_text
        @match[1]
    end
end


# This class is meant to be subclassed for implementing deprecated-markup 
# warnings as it is done in the markup-1-warn module.
class Deplate::DeprecatedParticle < Deplate::SimpleParticle
    def process
        Deplate::Core.log(["Deprecated text style", @match[0]], :error, @container.source)
        txt = get_text
        pre, post = get_prepost(@match)
        acc = [
            plain_text(pre.join, false),
            @deplate.format_particles(@elt),
            plain_text(post.join, false)
        ]
        @elt = acc.join
    end
end

# vim: ff=unix
