# encoding: ASCII
# guesslanguage.rb
# @Author:      Tom Link (micathom AT gmail com)
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     2006-12-29.
# @Last Change: 2009-11-09.
# @Revision:    0.1.80

require 'deplate/guesslanguage'

class Deplate::Core
    def deplate_initialize_guesslanguage
        @options.guesslanguage = Guesslanguage.new
        @options.guesslanguage_once = false
        @options.guesslanguage_collected = {}
        for dir in Deplate::Core.library_directories(@vanilla, true, ['locale'])
            for file in Dir[File.join(dir, '*_data')]
                lang = File.basename(file, '.*')
                text = File.read(file)
                @options.guesslanguage.register(lang, text)
                log(['Guesslanguage', lang, file])
            end
        end
    end

    def guesslanguage(text)
        if @variables['lang']
            log(['Guesslanguage', 'Variable already set', 'lang'])
            @options.guesslanguage_once = true
            return
        end
        unless text.empty? or @formatter.kind_of?(Deplate::Formatter::Template)
            text0 = text.gsub(/^\s*#.*$|^\s*%.*$|\{.*?\}/, '')
            if text0 =~ /\w/
                diff, lang = @options.guesslanguage.guess_with_diff(text0)
                if lang
                    lang0 = @options.guesslanguage_collected[:best]
                    diff0 = lang0 ? @options.guesslanguage_collected[lang0] : nil
                    if !diff0 or diff < diff0
                        log(['Guesslanguage: Switch to', lang])
                        if lang0 and lang0 != lang
                            log(['Guesslanguage: Possible conflict', lang, '%1.2f' % diff, lang0, '%1.2f' % diff0], :anyway)
                        end
                        @options.guesslanguage_collected[:best] = lang
                        @options.guesslanguage_collected[lang] = diff
                        @options.guesslanguage_once = true
                        set_lang(lang)
                    else
                        if lang != lang0
                            log(['Guesslanguage: Ignore switch', lang, '%1.2f' % diff, lang0, '%1.2f' % diff0])
                            log(text, :debug)
                            # p "DBG", text, text0
                        end
                    end
                end
            end
        end
    end

    alias :guesslanguage_include_each :include_each
    def include_each(enum, array, sourcename=nil)
        case enum
        when Array
            enum = enum.join("\n")
        end
        rv = nil
        lang = @@message_object.prop('lang')
        begin
            guesslanguage(enum) unless @options.guesslanguage_once
            rv = guesslanguage_include_each(enum, array, sourcename)
        ensure
            # TBD: Temporarily switch languages
            # if lang != @@message_object.prop('lang')
            #     log(['Guesslanguage: Switch to', lang])
            #     set_lang(lang)
            # end
        end
        return rv
    end
end

