# encoding: ASCII
# fmt-html.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     17-Mär-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.445

require "deplate/fmt/htmlslides"

# A variant of the html-formatter that generates website to please 
# Fritz Heinrichmeyer

class Deplate::Formatter::HTML_Website < Deplate::Formatter::HTML_Slides
    self.myname = "htmlwebsite"
    self.rx     = /html?|htmlslides|htmlwebsite/i

    def hook_pre_body_flush_html_pager
        # invoker = @deplate.accum_elements.last
        invoker = nil
        format_navigation_bar(invoker, :body, :navbar_top, :top)
    end
    
    def setup
        super
        @deplate.variables["headings"] = "plain"
    end
    
    def prepare
        super
        metaextra = @deplate.get_clip("metaextra")
        output_at(:pre, :head_beg, %{#{metaextra.elt if metaextra}})
        explorerhack=<<EOF
<style type="text/css">
@import url(./no_ns.css);
</style>
<!--[if gte IE 5]>
     <link href="./ie5.css" rel="stylesheet" type="text/css">
<![endif]-->
<link rel="shortcut icon" href="./favicon.ico" type="image/x-icon" />
<link rel="icon" href="./favicon.ico" type="image/x-icon" />
EOF
        output_at(:pre, :head_end, explorerhack)
    end 

    def format_navigation_bar(invoker, type, slot, bartype, first=false, last=false)
        idx, _, _ = navbar_output_index(invoker, first, last)
        navextra = @deplate.get_clip("navextra")
        navmenu  = [%{<span class="navmenuhead">#{navextra.elt if navextra}</span>} ]
        @deplate.each_heading(:top) do |section, title|
            unless section.args["noList"]
                f = section.output_file_name(:basename => true)
                v = section.description.gsub(/<\/?[^>]*>/, "")
            end
            if @deplate.top_heading_idx(section.top_heading) != idx
                navmenu << %{<a class="navbar" href="#{f}">#{v}</a>}
            else
                set_at(:pre, :head_title, %{<title>#{v}</title>})
                navmenu <<  %{<span class="navbartds">#{v}</span>}
            end
        end
        @deplate.options.navmenu = navmenu.join("\n")
        
        output_at(:body, slot, %{<div id="navigation">#{@deplate.options.navmenu}</div> <div id="contentframe"> <div id="innercontentframe"> <div id="content">})
        output_at(:body, :navbar_bottom, %{<br> </div> </div> </div>})
    end

    alias :format_paragraph :format_paragraph_html
end

