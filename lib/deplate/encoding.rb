# encoding.rb
# @Author:      Tom Link (micathom AT gmail com)
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     2009-02-04.
# @Last Change: 2009-11-09.
# @Revision:    0.0.4

# require ''

module Deplate::Encoding

    module_function

    def ruby_enc_name(enc)
        case enc.downcase
        when 'latin-1', 'latin1', 'l1', 'isolat1', 'iso-8859-1'
            cen = 'iso-8859-1'
        when 'latin-9', 'latin9', 'l9', 'isolat9', 'iso-8859-15'
            cen = 'iso-8859-15'
        when 'gb2312', 'gbk'
            cen = 'gb2312'
        when 'koi8-r'
            cen = 'koi8-r'
        when 'utf8', 'utf-8'
            cen = 'utf-8'
        else
            log(['Unsupported ruby encoding', enc], :anyway)
            cen = enc
        end
        return cen
    end

    def canonic_enc_name(enc, table=@encodings)
        case enc.downcase
        when 'latin-1', 'latin1', 'l1', 'isolat1', 'iso-8859-1'
            cen = 'latin1'
        when 'latin-9', 'latin9', 'l9', 'isolat9', 'iso-8859-15'
            cen = 'latin9'
        when 'gb2312', 'gbk'
            cen = 'gb2312'
        when 'koi8-r'
            cen = 'koi8-r'
        when 'utf8', 'utf-8'
            cen = 'utf-8'
        else
            log(['Unsupported encoding', enc], :anyway)
            cen = enc
        end
        return (table && table[cen]) || cen
    end

end


# Local Variables:
# revisionRx: REVISION\s\+=\s\+\'
# End:
