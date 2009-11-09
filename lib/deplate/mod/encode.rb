# encode.rb
# @Author:      Tom Link (micathom AT gmail com)
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     2009-02-03.
# @Last Change: 2009-11-09.
# @Revision:    0.0.5


raise 'mod/encode requires Ruby 1.9.1 or higher' unless RUBY_VERSION >= '1.9.1'

class Deplate::Formatter

    def plain_text_recode(text)
        enc = @deplate.variables['encoding']
        if enc
            begin
                return text.encode(enc)
            rescue Exception => e
                p e
                p Encoding.default_internal
                p Encoding.default_external
                p enc, text, text.encoding
            end
        end
        return text
    end

end


# Local Variables:
# revisionRx: REVISION\s\+=\s\+\'
# End:
