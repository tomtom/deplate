# encoding: ASCII
# html-headings-navbar.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     15-Nov-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.48

class Deplate::Formatter::HTML
    def formatter_initialize_headings_navbar
        def_advice("html-headings-navbar", :format_heading,
                  :wrap => Proc.new do |agent, rv, invoker, *rest|
                    max_level = @deplate.variables["headingsNavbarMaxLevel"]
                    if max_level
                        max_level = max_level.to_i
                    else
                        max_level = 1
                    end
                    if invoker.level <= max_level
                        nb = invoke_service("navigation_bar",
                                            :invoker => invoker,
                                            'noNavButtons' => true)
                        join_blocks([nb, rv])
                    else
                        rv
                    end
                  end
                 )
    end
end

