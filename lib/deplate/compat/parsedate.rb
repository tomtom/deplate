# parsedate.rb
# @Author:      Tom Link (micathom AT gmail com)
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     2009-01-22.
# @Last Change: 2009-11-09.
# @Revision:    0.0.5

require 'deplate/compat'

if Deplate::Compat.isRuby19

    require 'date'
    class ParseDate
        def parsedate(date, guess=false)
            Date.parse(date, guess)
        end
    end

else

    require 'parsedate'

end

