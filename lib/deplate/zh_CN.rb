# encoding: ASCII
# zh-cn.rb -- Simplified Chinese messages
# @Author:      Tom Link; localization by Jjgod Jiang (gzjjgod AT 21cn com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     01-Aug-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.220

require 'deplate/messages'

class Deplate::Formatter
    attr_reader :cjk_smart_blanks
    
    def hook_pre_setup_zh_cn
        # @deplate.variables['encoding'] = 'GB2312'
        @cjk_smart_blanks = !(@deplate.variables['noSmartBlanks'] || false)
    end
end

class Deplate::Formatter::LaTeX
    def prepare_zh_cn
        family   = @deplate.variables['cjk_family']   || 'gbsn'
        encoding = @deplate.variables['cjk_encoding'] || 'GB'
        union_at(:pre, :mod_packages, '\\usepackage{CJK}')
        union_at(:pre, :mod_packages, '\\usepackage{CJKnumb}')
        union_at(:pre, :mod_packages, '\\usepackage{indentfirst}')
        output_at(:pre, :body_beg, "\\begin{CJK*}{#{encoding}}{#{family}}", 
                        '\\CJKtilde{}', '\\CJKcaption{GB}', '\\CJKindent{}')
        output_at(:post, :prepend_body_end, '\\end{CJK*}')
    end

    def set_document_encoding
    end
end

class Deplate::Formatter
    def multibyte_leader?(ch)
        ch && ch >= 0xA1 && ch <= 0xFE
    end
    
    alias :get_first_char_re_zh_cn :get_first_char
    
    def get_first_char(string, upcase=false)
        if multibyte_leader?(string[0])
            string[0..1]
        else
            get_first_char_re_zh_cn(string, upcase)
        end
    end
end

class Deplate::Messages::ZhCnGb2312 < Deplate::Messages
    setup 'zh_CN'
    def_prop 'lang', 'zh_CN'
    def_prop 'encoding', 'GB2312'
    def_prop 'latex_encoding', nil
    load_catalog 'zh_CN.GB2312'
end

