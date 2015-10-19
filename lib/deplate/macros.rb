# encoding: ASCII
# macros.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     25-Mär-2004.
# @Last Change: 2015-10-18.
# @Revision:    2.1372

require 'forwardable'

# Deplate::Macro is responsible for dealing with macros in curly braces 
# like {fn: foo} or {cite p=42: bar}.

class Deplate::Macro < Deplate::BaseParticle
    extend Forwardable

    @@macros = {}

    class << self
        def macros
            @@macros
        end
 
        def register_as(name, c=self)
            @@macros[name] = c
        end
 
        def exec(deplate, container, context, cmd, *args)
            c = deplate.input.macros[cmd]
            if c.nil?
                m = /^([[:alnum:]_]+)(\[.*?\])?(\.|!)?/.match(cmd)
                if m
                    if deplate.clips[m[1]]
                        args[2] = cmd
                        c = deplate.input.macros['get']
                    elsif deplate.variables.include?(m[1])
                        if m[3]
                            args[2] = cmd[0..-2]
                            c = deplate.input.macros['var']
                        else
                            args[2] = cmd
                            c = deplate.input.macros['arg']
                        end
                    end
                end
            end
            if c
                begin
                    return c.new(deplate, container, context, *args)
                rescue Exception => e
                    # puts e.backtrace[0..10].join("\n")
                    puts 'Internal error when initializing ' + c.name
                    raise e
                end
            else
                container.log(['Unknown macro', cmd, args.inspect], :unknown_macro)
                # p "DBG", deplate.formatter.class, @container.class
                # puts caller.join("\n")
            end
        end
    end

    def initialize(deplate, container, context, args, alt, text)
        super(deplate, 
              :container => container, 
              :source => container.source,
              :args   => args
             )
        @args[:self] ||= self
        @context       = context
        @alt           = alt
        update_styles
        setup(text)
    end

    # def_delegator(:@container, :out)
    #
    def log(*args)
        @container.log(*args)
    end

    def setup(text)
    end

    def process_elt
        @elt.collect!{|e| e.process; e.elt}
        @elt = @elt.compact
    end
    
    def join_elt(sep='')
        process_elt
        if block_given?
            yield
        end
        @elt = @elt.join(sep)
    end

    # #process gives a macro the opportunity to do something after the whole 
    # file was read in and parsed. It returns the ready format result.
    def process
        if @elt
            return join_elt
        elsif @text
            return @text
        else
            return ''
        end
    end
end


class Deplate::Macro::Unknown < Deplate::Macro
    def setup(text)
        text = @args[:match][0][1..-2]
        # @elt = plain_text(text)
        @elt = @deplate.parse(@container, text, @alt, :pcontainer => self)
    end
    
    def process
        join_elt
        return format_particle(:format_unknown_macro, self)
    end
end


class Deplate::Macro::Footnote < Deplate::Macro
    register_as 'fn'
    include Deplate::Footnote
    alias :setup :footnote_setup
    alias :process :footnote_process
end


class Deplate::Macro::Cite < Deplate::Macro
    register_as 'cite'
    attr :elt
    
    def setup(text)
        @deplate.options.citations << self
        @elt = Deplate::Core.split_list(text, ',', ';', @source)
        for c in @elt
            @container.add_metadata(@source,
                                    "type" => "citation", 
                                    "name" => c
                                   )
        end
    end

    def process
        return format_particle(:format_cite, self)
    end
end


class Deplate::Macro::Attr <  Deplate::Macro
    register_as 'attr'
    register_as 'attrib'
    
    def setup(text)
        attrib, text = @deplate.input.parse_args(text, @container)
        context.last.args.update(attrib)
        context.last.update_args
    end
end


class Deplate::Macro::EProp <  Deplate::Macro
    register_as 'eprop'
    
    def setup(text)
   		@container.unify_args(@args)
	end
end


class Deplate::Macro::Date <  Deplate::Macro
    register_as 'date'
    
    def setup(text)
        @text = plain_text(Deplate::Element.get_date(text, @args))
    end
end


class Deplate::Argument < Deplate::Macro
    def value(text)
        @deplate = @deplate.options.master if @deplate.options.master
        val      = @deplate.variables[text]
        if val.nil?
            val = @args['default']
            log(['Unknown variable', '{arg}', text]) if val.nil?
        end
        transformed_value(val)
    end
   
    def transformed_value(val)
        case val
        when Array
            if (j = @args['join'])
                return val.join(j)
            end
        when Hash
            if @args['keys']
                return transformed_value(val.keys)
            elsif @args['values']
                return transformed_value(val.values)
            elsif @args['join']
                return transformed_value(val.to_a)
            end
        end
        return val
    end

    def process
        post_process_text(super)
    end
end


# Access document options set with DOC.
class Deplate::Macro::Var < Deplate::Argument
    register_as 'doc'
    register_as 'var'
    
    def setup(text)
        val = value(text)
        unless val.nil?
            @text = plain_text(val.inspect)
        end
    end
end


# Access template arguments or document options set with DOC and parse.
class Deplate::Macro::Arg < Deplate::Argument
    register_as 'arg'
    register_as 'val'
    
    def setup(text)
        val = value(text)
        unless val.nil?
            case val
            when String
                @text = val
            when Array
                @text = val.join(' ')
            # when TrueClass
            #     @text = '{true}'
            # when FalseClass
            #     @text = '{false}'
            # when Numeric
            #     @text = "{0d#{val}}"
            else
                # @text = val.to_s
                @text = val.inspect
            end
            @text = Deplate::Core.escape_characters(@text, @args)
            if !@args['asString']
                @elt = @deplate.parse(@container, @text, @alt, :pcontainer => self, :args => args)
            end
        end
    end
end


# Access template arguments or document options set with DOC and parse.
class Deplate::Macro::XArg < Deplate::Argument
    register_as 'xarg'
    register_as 'xval'
    
    def setup(text)
        c = @deplate.variables[text] || @args["default"]
        if c
            c = Deplate::Core.escape_characters(c, @args)
            @elt  = @deplate.parse(@container, c, @alt, :pcontainer => self)
        else
            log(["Unknown variable", '{xarg}', text])
        end
    end
end


# Access element options set with OPT
class Deplate::Macro::Opt < Deplate::Macro
    register_as 'opt'

    def setup(text)
        @text = plain_text(@container.args[text])
    end
end


# Access element options set with OPT
class Deplate::Macro::Msg < Deplate::Macro
    register_as 'msg'

    def setup(text)
        @elt  = @deplate.parse(@container, @deplate.msg(text), @alt, :pcontainer => self)
        # @text = @deplate.msg(text)
    end
end


# Access clips (probably requires some processing?)
class Deplate::Macro::Clip < Deplate::Macro
    register_as 'clip'
    register_as 'get'

    def setup(text)
        @id      = text
        # @clip    = @deplate.get_clip(@id)
    end
    
    def process
        if @id
            # ???<+TBD+>
            # @elt = @clip || @deplate.get_clip(@id)
            @elt = @deplate.get_clip(@id)
            if @elt
                return @elt.format_clip(self, Deplate::Particle)
            # elsif (var = @deplate.variables[@id])
            #     return @deplate.parse_and_format(@container, var.to_s)
            elsif (default = @args['default'])
                return default
            else
                log(['Unknown clip', @id], :error) unless @elt
            end
        else
            log(['No ID given', @id], :error)
        end
    end
end


# Insert some native text
class Deplate::Macro::Insert < Deplate::Macro
    register_as 'ins'
    register_as 'native'

    def setup(text)
        @text = text
    end
end


# Evaluate some ruby code
class Deplate::Macro::Ruby < Deplate::Macro
    register_as 'ruby'

    def setup(text)
        rv = @deplate.eval_ruby(self, @args, text)
        if rv
            rv = rv.to_s
            if @args['native'] or @args['ins']
                @text = rv
            else
                @elt = @deplate.parse(self, rv, @alt, :pcontainer => self)
            end
        end
    end
end


# Reference to an anchor in the current document
# {ref: label}, {ref p!: label}
class Deplate::Macro::Ref < Deplate::Macro
    register_as 'ref'
   
    def setup(text)
        @text = text
    end
    
    def process
        # id = @args["byId"]
        # if id
        #     @text = @deplate.get_label_by_id(self, id)
        #     unless @text
        #         log(["Cannot refer to ID", id], :error)
        #     end
        # end
        return format_particle(:format_ref, self)
    end
end


class Deplate::Macro::Label < Deplate::Macro
    register_as 'anchor'
    register_as 'label'
    register_as 'lab'
    
    def setup(text)
        @deplate.add_label(self, text, level_as_string, :container => @container)
        @text = format_particle(:format_label, self, :string, [text])
    end
end


class Deplate::Macro::LineBreak < Deplate::Macro
    register_as 'nl'

    def process
        return format_particle(:format_linebreak, self)
    end
end


class Deplate::Macro::Latex < Deplate::Macro
    register_as 'ltx'
    register_as 'latex'
    set_formatter :format_ltx

    attr_reader :accum, :caption

    def setup(text)
        prelude = @deplate.formatter.prelude('ltxPrelude')
        @accum  = [ prelude, text ].flatten.compact
        @text   = text
        @args['inline'] = true
        @deplate.formatter.inlatex(self)
    end

    def process
        format_particle(self.class.formatter, self)
    end
end

class Deplate::Macro::Math < Deplate::Macro::Latex
    register_as 'math'
    register_as '$'
    set_formatter :format_math
    
    def setup(text)
        prelude = @deplate.formatter.prelude('mathPrelude')
        fmt     = is_block? ? '\\[%s\\]' : '$%s$'
        @text   = [prelude, fmt % text].flatten.compact.join("\n")
        super(@text)
    end

    def is_block?
        return @args['block']
    end
end

class Deplate::Macro::List < Deplate::Macro
    attr_reader :type

    register_as 'list'
    
    def setup(text)
        @elt = @deplate.parse(self, text, @alt, :pcontainer => self)
        case @args['type']
        when 'dl'
            @type = 'Description'
        when 'ol'
            @type = 'Ordered'
        else
            @type = 'Itemize'
        end
    end
    
    def process
        b = format_particle(:format_list_env, self, @type, 0, :open)
        join_elt("\n") do
            @elt.delete_if {|x| x =~ /^\s*$/}
        end
        e = format_particle(:format_list_env, self, @type, 0, :close)
        if @elt =~ /\S/m
            return [b, @elt, e].flatten.compact.join
        else
            return ''
        end
    end
end


class Deplate::Macro::Item < Deplate::Macro
    register_as 'item'
    
    def setup(text)
        @elt = @deplate.parse(@container, text, @alt, :pcontainer => self)
    end
    
    def process
        join_elt
        type = @container.type
        @elt = Deplate::ListItem.new(nil, @elt, type, type)
        rv = format_particle(:format_list_item, self, type, 0, @elt)
        rv.delete(:none)
        rv.delete(:empty)
        rv
    end
end


class Deplate::Macro::Term < Deplate::Macro
    register_as 'term'
    
    def setup(text)
        @elt = @deplate.parse(@container, text, @alt, :pcontainer => self)
    end

    def process
        join_elt
        type = @container.type
        @elt = Deplate::ListItem.new(plain_text(@args["id"]), @elt, type, type)
        rv = format_particle(:format_list_item, self, type, 0, @elt)
        rv.delete(:none)
        rv
    end
end


class Deplate::Macro::Subscript < Deplate::Macro
    register_as ','
    register_as 'sub'
    
    def setup(text)
        @elt = @deplate.parse(@container, text, @alt, :pcontainer => self)
    end

    def process
        join_elt
        return format_particle(:format_subscript, self)
    end
end


class Deplate::Macro::Superscript < Deplate::Macro
    register_as '^'
    register_as 'sup'
    register_as 'super'
    
    def setup(text)
        @elt = @deplate.parse(@container, text, @alt, :pcontainer => self)
    end

    def process
        join_elt
        return format_particle(:format_superscript, self)
    end
end


class Deplate::Macro::Stacked < Deplate::Macro
    register_as '%'
    register_as 'stacked'
    
    def setup(text)
        @elt = @deplate.parse(@container, text, @alt, :pcontainer => self)
    end

    def process
        process_elt
        @elt.delete("")
        log(["Size of stacked macro's element != 2", @text], :error) if @elt.size != 2
        return format_particle(:format_stacked, self)
    end
end


class Deplate::Macro::Text < Deplate::Macro
    register_as ':'
    register_as 'text'
    
    def setup(text)
        @elt = @deplate.parse(@container, text, @alt, :pcontainer => self)
    end

    def process
		e = super
        format_particle(:format_void, self, e)
    end
end


class Deplate::Macro::FirstTimeUppercase < Deplate::Macro::Text
    register_as 'mark1st'
    register_as '~'
    @@uc1st_textbits = []

    def setup(text)
        anyway = @args['anyway'] || @args['always']
        itext  = @args['text']   || text
        if anyway or !@@uc1st_textbits.include?(itext)
            @@uc1st_textbits << itext
            if (style = @deplate.variables['mark1stStyle'])
                push_styles(style)
            else
                text = text.upcase
            end
        elsif (alt = @args['alt'])
            push_styles(alt)
        end
        super(text)
    end
end


class Deplate::Macro::Upcase < Deplate::Macro::Text
    register_as 'upcase'

    def setup(text)
        text = text.upcase
        super(text)
    end
end


class Deplate::Macro::Downcase < Deplate::Macro::Text
    register_as 'downcase'

    def setup(text)
        text = text.downcase
        super(text)
    end
end


class Deplate::Macro::Capitalize < Deplate::Macro::Text
    register_as 'capitalize'

    def setup(text)
        text = text.capitalize
        super(text)
    end
end


class Deplate::Macro::Plain < Deplate::Macro
    register_as 'plain'
    register_as '\\'
    
    def setup(text)
        @text = plain_text(text)
    end
end


class Deplate::Macro::FormattedText < Deplate::Macro
    def setup(text)
        @elt = @deplate.parse(@container, text, @alt, :pcontainer => self)
    end
end


class Deplate::Macro::Emphasize < Deplate::Macro::FormattedText
    register_as 'em'
    register_as 'emph'
    register_as '_'
    
    def process
        format_particle(:format_emphasize, self, super)
    end
end


class Deplate::Macro::Code < Deplate::Macro
    register_as 'code'
    register_as 'verb'
    register_as "'"
    
    def setup(text)
        @text = format_particle(:format_code, self, text)
    end
end


class Deplate::Macro::Image < Deplate::Macro
    register_as 'img'
    
    def setup(text)
        @text = text
    end

    def process
        return @deplate.formatter.include_image(self, @text, @args, true)
    end
end


class Deplate::Macro::Comment < Deplate::Macro
    register_as 'cmt'
end


class Deplate::Macro::Pagenumber < Deplate::Macro
    register_as 'pagenumber'
    register_as 'pagenum'
    
    def setup(text)
        @elt = @deplate.parse(@container, text, @alt, :pcontainer => self)
    end

    def process
        rv = format_particle(:format_pagenumber, self)
        unless rv.empty?
            join_elt
            rv += @elt
        end
        return rv
    end
end


class Deplate::Macro::Idx < Deplate::Macro
    register_as 'idx'
    
    def setup(text)
        @acc = Deplate::Command::IDX.get_indices(@container, @deplate, @args, text, @source)
    end

    def process
        @text = []
        for i in @acc
            @text << format_particle(:format_index, self, i)
        end
        @text = @text.join
        super
    end
end


class Deplate::Macro::Let < Deplate::Macro
    register_as 'let'
    
    def setup(text)
        args = {}
        for key, val in @args
            val1 = @deplate.variables[val]
            args[key] = val1 || val
        end
        Deplate::Define.let_variables(@deplate, args) do
            @elt = @deplate.parse(@container, text, @alt, :pcontainer => self)
        end
    end
end


class Deplate::Macro::Counter < Deplate::Macro
    register_as 'counter'
    
    def setup(text)
        @text = @deplate.options.counters.get_s(text, @args)
    end
end


class Deplate::Macro::Nop < Deplate::Macro
    register_as 'nop'
    
    def setup(text)
        @text = ''
    end
end


class Deplate::Core
    def self.simple_macro(name, body)
        cn = name.capitalize
        cn.gsub!(/\W/, '_')
        eval %{
            class Deplate::Macro::#{cn} < Deplate::Macro
                register_as #{name.inspect}
                def setup(text)
                    @text = plain_text(#{body})
                end
            end
        }
    end
end

# vim: ff=unix
