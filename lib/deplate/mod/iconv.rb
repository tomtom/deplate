# encoding: ASCII
# iconv.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     11-Apr-2005.
# @Last Change: 2009-11-09.
# @Revision:    0.87
#
# = Description
# Recode text on-the-fly using +iconv+. The source encoding is 
# taken from the +encoding+ variable (default: latin1), the target 
# encoding is defined in the +recodeEncoding+ (default: utf-8) variable.

require 'iconv'

class Deplate::Formatter
    def hook_pre_go_iconv
        @iconv_encodings = {}
        unless defined?(@iconv_enc_source)
            source            = @deplate.variables['encoding'] || "latin1"
            @iconv_enc_source = canonic_enc_name(source, @iconv_encodings)
            target            = @deplate.variables['recodeEncoding'] || "utf-8"
            @iconv_enc_target = canonic_enc_name(target, @iconv_encodings)
            @deplate.variables['encoding'] = target
        end
        unless defined?(@iconv_converter) and @iconv_converter
            @iconv_converter = Iconv.new(@iconv_enc_target, @iconv_enc_source)
        end
    end

    def plain_text_recode(text)
        @iconv_converter.iconv(text)
    end
end

