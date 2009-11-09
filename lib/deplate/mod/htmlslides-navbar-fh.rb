# encoding: ASCII
# htmlslides-navbar-fh.rb
# @Author:      Tom Link, Fritz Heinrichmeyer
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     17-Mär-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.439


class Deplate::Formatter::HTML_Site
    def format_navigation_bar(invoker, type, slot, bartype, first=false, last=false)
      idx, _, _ = navbar_output_index(invoker, first, last)
      navmenu  = []
      doctitle = @deplate.get_clip("title")
      doctitle = if doctitle then  doctitle.elt.to_s else "" end
      @deplate.each_heading(:top) do |section, title|
        unless section.args["noList"]
          f = section.output_file_name
          v = section.description.gsub(/<\/?[^>]*>/, "")
        end
        if @deplate.top_heading_idx(section.top_heading) != idx
          navmenu << %{<a class="navbar" href="#{f}">#{v}</a>}
        else
          set_at(:pre, :head_title, %{<title>#{doctitle} #{v}</title>})
          navmenu <<  %{<span class="navbartds">#{v}</span>}
        end
      end
      @deplate.options.navmenu = navmenu.join("\n")
      output_at(:body, slot, @deplate.options.navmenu.to_s)
    end
end

