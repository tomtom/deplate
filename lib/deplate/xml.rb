# encoding: ASCII
# xml.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     17-Mär-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.2336

require 'deplate/structured'

# An abstract xml formatter
class Deplate::Formatter::XML < Deplate::Formatter::Structured
    self.suffix = '.xml'

    def initialize(deplate, args)
        deplate.options.indentation_level = [0]
        super
        @special_symbols = {
            '"'  => Proc.new {|e| symbol_quote(nil)},
            '&'  => Proc.new {|e| symbol_amp(nil)},
            # '§'  => Proc.new {|e| symbol_paragraph(nil)},
            '<'  => Proc.new {|e| symbol_lt(nil)},
            '>'  => Proc.new {|e| symbol_gt(nil)},
            ' '  => Proc.new {|e| e ? nonbreakingspace(nil) : ' '},
        }
        build_plain_text_rx
        @encodings = {
            'latin1' => 'ISO-8859-1',
            'latin9' => 'ISO-8859-15',
        }
    end
    
    def pre_process
        super
        @encoding = canonic_enc_name(@deplate.variables['encoding'] || 'utf-8')
        if @deplate.options.symbols_encoding
            symbols = @deplate.options.symbols_encoding
        elsif @deplate.variables['sgml']
            symbols = :sgml
            require 'deplate/mod/symbols-sgml' unless @deplate.symbols[symbols]
            @sgml   = true
        else
            case @encoding
            when 'ISO-8859-1', 'ISO-8859-15'
                symbols = 'ISO-8859-1'
                require 'deplate/mod/symbols-latin1' unless @deplate.symbols[symbols]
            else
                symbols = :xml
                require 'deplate/mod/symbols-xml' unless @deplate.symbols[symbols]
            end
        end
        if @sgml
            require 'deplate/mod/noindent'
            Deplate::NoIndent.setup(self)
        end
        klass = @deplate.symbols[symbols]
        if klass
            @symbol_proxy = klass.new(@deplate)
        else
            raise 'Unknown symbols encoding: %s (%s)' % [symbols, @deplate.symbols.keys.join(', ')]
        end
        @deplate.variables['refButton'] ||= '[%s]' % format_symbol(nil, '->')
    end
    
    def prepare
        creator = ['===================================================',
            '== Created with deplate (http://deplate.sf.net) ==',
            '===================================================']
        output_at(:pre, :doc_def,   get_doc_def({:deplate => @deplate}))
        output_at(:pre, :doc_def,   get_comment(creator))
        output_at(:pre, :doc_beg,   get_doc_open({}))
        output_at(:pre, :head_beg,  get_doc_head_open({}))
        output_at(:pre, :head,      indent_text(get_doc_head({})))
        output_at(:pre, :head_end,  get_doc_head_close({}))
        output_at(:pre, :body_beg,  get_doc_body_open({}))

        @deplate.postponed_print << Proc.new do
            output_at(:body, :inner_body_end, close_headings(0))
            output_at(:post, :body_end, get_doc_body_close({}))
            output_at(:post, :doc_end,  get_doc_close({}))
        end
    end

    def plain_text(text, escaped=false, vapor_space=true)
        # p "DBG", text, caller[0..3]
        super(text, escaped) do |accum|
            if vapor_space
                accum.join.gsub(/ {2,}/, ' ')
            else
                accum.join
            end
        end
    end

    def encode_id(text)
        text ? text.gsub(/\W/, '00') : ''
    end

    def get_comment(strings)
        strings.collect {|l| %{<!-- %s -->} % l}.join("\n")
    end

end

# vim: ff=unix
