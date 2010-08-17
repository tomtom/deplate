# encoding: ASCII
# iconv.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     11-Apr-2005.
# @Last Change: 2010-08-17.
# @Revision:    0.115
#
# = Description
# Recode text on-the-fly using +iconv+. The source encoding is 
# taken from the +encoding+ variable (default: latin1), the target 
# encoding is defined in the +recodeEncoding+ (default: utf-8) variable.

require 'iconv'

class Deplate::Formatter

    def hook_pre_go_iconv
        @iconv_encodings = {}
        @iconv_converters = {}
    end


    def iconv_get_converter(from_enc, to_enc)
        key = [from_enc, to_enc].join(' ')
        @iconv_converters[key] ||= Iconv.new(to_enc, from_enc)
    end


    def plain_text_recode(text, from_enc=nil, to_enc=nil)
        from_enc = canonic_enc_name(from_enc || @deplate.variables['encoding'] || "latin1", @iconv_encodings)
        to_enc = canonic_enc_name(to_enc || @deplate.variables['recodeEncoding'] || "utf-8", @iconv_encodings)
        # @deplate.variables['encoding'] ||= to_enc
        if from_enc != to_enc
            iconv_get_converter(from_enc, to_enc).iconv(text)
        else
            text
        end
    end

end

