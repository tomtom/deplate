# encoding: ASCII
# mod-en.rb -- Standard messages
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     07-Mai-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.214

# The base class for localizations
class Deplate::Messages
    class << self
        def setup(lang)
            @properties ||= {}
            @catalog    ||= {}
            Deplate::Core.module_eval <<-CODE
                @@messages['#{lang}'] = #{self.name}
                @@messages_last = #{self.name}
            CODE
        end

        # Obsolete. Messages should be defined in a file in the locale 
        # subdirectory
        def def_msg(id, text)
            @catalog[id] = text
        end
      
        # Define a "property" like lang, latex_cmd etc.
        def def_prop(key, val)
            @properties[key] = val
        end

        # Get the localized message with this id
        def msg(id)
            case id
            when Symbol
                mid = "@#{id}"
            else
                mid = id
            end
            rv = @catalog[mid] || (id.kind_of?(String) ? id : nil)
            rv
        end

        # was property key defined?
        def has_property?(key)
            @properties.keys.include?(key)
        end

        # get property key; check if there exists a specific property for 
        # the formatter fmt (e.g., latex_lang instead of lang)
        def prop(key, fmt=nil)
            if fmt
                if fmt.kind_of?(String)
                    fmt_names = [fmt]
                else
                    fmt_names = fmt.class.formatter_family_members
                end
                for fmt_name in fmt_names
                    af = [fmt_name, key].join('_')
                    if has_property?(af)
                        return @properties[af]
                    end
                end
            end
            return @properties[key]
        end

        # Load the message catalog for lang from the locale subdirectory
        #
        # The format is simply (repeating):
        # MESSAGE/ID/HEAD/KEY
        # LOCALIZED TEXT
        # <BLANK LINE>
        #
        # Filter out comments -- lines starting with # in the first 
        # position. Comments can only occur in the head/key position as 
        # there is no message starting with #.
        def load_catalog(lang)
            langs, catalogs = Deplate::Core.collect_deplate_options('locale', 'locale', 
                                                                    :suffix => '')
            fname = catalogs[lang]
            if fname
                cat = []
                File.open(fname) do |io|
                    cat = io.readlines
                end
                key  = nil
                text = []
                for e in cat
                    e.chomp!
                    if key
                        if e =~ /^\s*$/
                            @catalog[key] = text.join("\n")
                            key  = nil
                            text = []
                        else
                            text << e
                        end
                    elsif e !~ /^#/ and e !~ /^\s*$/
                        key = e
                    end
                end
            else
                raise "Unknown language: #{lang} (#{catalogs.keys.join(', ')})"
            end
        end

    end

    def initialize(deplate)
        @deplate = deplate
        encoding = prop('encoding')
        if encoding
            vencoding = @deplate.variables['encoding']
            if vencoding
                encoder = @deplate.formatter || Deplate::Encoding
                if encoder.canonic_enc_name(vencoding) != encoder.canonic_enc_name(encoding)
                    @deplate.log(['Document encoding does not match message encoding', vencoding, encoding], :error)
                end
            else
                @deplate.variables['encoding'] = encoding
            end
        end
        @deplate.options.lang = prop('lang', false)
    end

    # See Deplate::Messages.msg
    def msg(key)
        self.class.msg(key)
    end
    
    # See Deplate::Messages.prop
    def prop(key, fmt=nil)
        fmt = @deplate.formatter if fmt.nil?
        self.class.prop(key, fmt)
    end

end

