# encoding: ASCII
#!/usr/bin/env ruby
# entities.rb
# @Last Change: 2009-11-09.
# Author::      Tom Link (micathom AT gmail com)
# License::     GPL (see http://www.gnu.org/licenses/gpl.txt)
# Created::     2007-11-28.


class Deplate::Core
    def module_initialize_entities_encode
        @formatter.setup_entities
    end
end

class Deplate::Formatter
    alias :entities_encode_plain_text :plain_text
    def plain_text(text, escaped=false)
        if escaped
            entities_encode_plain_text(text, escaped)
        else
            ntxt = []
            max  = text.size
            idx  = 0
            while idx < max
                catch(:next) do
                    # This probably is the most inefficient way to do this. 
                    # On the other hand, "char" could be about any byte 
                    # sequence you want.
                    @deplate.formatter.entities_table.each do |char, named, numbered|
                        i = idx + char.size
                        j = i - 1
                        if text[idx..j] == char
                            ntxt << (named.nil? || named.empty? ? numbered : named)
                            idx = i
                            throw :next
                        end
                    end
                    ntxt << text[idx..idx]
                    idx += 1
                end
            end
            return ntxt.join
        end
    end
end


# Local Variables:
# revisionRx: REVISION\s\+=\s\+\'
# End:
