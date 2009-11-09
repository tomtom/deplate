# encoding: ASCII
# utf8.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     10-Apr-2005.
# @Last Change: 2009-11-09.
# @Revision:    0.28
#
# = Description
# This file provides improved utf-8 support.

class Deplate::Formatter
    def multibyte_leader?(ch)
        ch && ch >= 0b11000000
    end

    alias :get_first_char_re_utf8 :get_first_char

    def get_first_char(string, upcase=false)
        ch = string[0]
        if multibyte_leader?(ch)
            if ch >= 0b11110000
                string[0..3]
            elsif ch >= 0b11100000
                string[0..2]
            else
                string[0..1]
            end
            # acc = "" << ch
            # string[1..-1].each_byte do |ch|
            #     if ch >= 0b10000000 and !multibyte_leader?(ch)
            #         acc << ch
            #     else
            #         break
            #     end
            # end
            # acc
        else
            get_first_char_re_utf8(string, upcase)
        end
    end
end

class Deplate::Core
    def module_initialize_utf8
        @variables['encoding'] = 'UTF-8'
    end
end

