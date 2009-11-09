# encoding: ASCII
# htmlsite.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     17-Mär-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.1029

require "deplate/fmt/html"

# A variant of the html-formatter that suppresses paragraphs and creates new 
# files on page breaks and level-1 headings.
#
# Press a-n or double-click on a heading to jump to the next slide. Press a-b 
# to jump to the previous one.
# 

class Deplate::Formatter::HTML_Site < Deplate::Formatter::HTML
    self.myname = 'htmlsite'
    self.rx     = /html?|htmlwebsite/i

    def hook_pre_body_flush_html_pager
        title = @deplate.get_clip('title')
        title = title.elt if title
        top   = @deplate.output.top_heading
        if top
            top_title = top.description
            if top_title
                title = clean_tags([title, top_title].compact.join(' -- '))
                set_at(:pre, :head_title, %{<title>%s</title>} % title) unless title.empty?
            end
        end
        
        invoker = nil
        navbar  = @variables['docNavbar']
        if navbar
            case navbar
            when 'top'
                format_navigation_bar(invoker, :body, :navbar_top,    :top)
            when 'bottom'
                format_navigation_bar(invoker, :body, :navbar_bottom, :bottom)
            else
                format_navigation_bar(invoker, :body, :navbar_top,    :top)
                format_navigation_bar(invoker, :body, :navbar_bottom, :bottom)
            end
        end

        idx = @deplate.output_index - 1
        set_relation(:htmlsite_prev, 'Prev', 'previous')
        set_relation(:htmlsite_next, 'Next', 'next')
        set_relation(:htmlsite_up,   'Home', 'up') if idx > 0
    end

    def set_relation(slot, service_infix, tag)
        url = invoke_service("page#{service_infix}Dest")
        if url
            title = invoke_service("page#{service_infix}Title") || tag
            title = clean_tags(title)
            set_at(:pre, slot, head_link_tag(%{rel="#{tag}" href="#{url}" title="#{title}"}))
        end
    end
        
    def setup
        @deplate.options.multi_file_output = true if @deplate.options.multi_file_output.nil?
        super
    end

    # for web sites, a pagebreak means navigation bars + a new file
    def format_pagebreak(invoker, html_class=nil, major=false)
        if major
            invoker.postponed_format << lambda {|e| @deplate.break_output}
            unless @deplate.body_empty?
                return format_label(invoker, :closeOpen)
            end
            return nil
        else
            return super
        end
    end

    def format_heading(invoker)
        if invoker.is_top_heading?
            output_at(:body, :inner_body_end, %{</div>\n})
            [super, %{<div class="pagebody">\n}].join
        else
            super
        end
    end


    def_service('tab_bar_note') do |args, text|
        unless defined?(@htmlsite_sliding_tabbar_note)
            @htmlsite_sliding_tabbar_note = @deplate.msg(:htmlsite_tabbar_note)
        end
        @htmlsite_sliding_tabbar_note
    end

    def_service('tab_bar_left') do |args, text|
        htmlsite_tabbar(args, text, 'tabBarLeft', false)
    end
    
    def_service('tab_bar_right') do |args, text|
        htmlsite_tabbar(args, text, 'tabBarRight', false)
    end

    def_service('tab_bar_top') do |args, text|
        htmlsite_tabbar(args, text, 'tabBarTop', true)
    end

    def_service('tab_bar_bottom') do |args, text|
        htmlsite_tabbar(args, text, 'tabBarBottom', true)
    end

    def_service('progress_bar') do |args, text|
        horizontal = !args['vertical']
        htmlsite_progress_bar(args, horizontal)
    end
    
    def_service('progress_bar_horizontal') do |args, text|
        htmlsite_progress_bar(args, true)
    end
    
    def_service('progress_bar_vertical') do |args, text|
        htmlsite_progress_bar(args, false)
    end
    
    def_service('progress_percent') do |args, text|
        idx     = @deplate.output_index
        percent = 100 * idx / @deplate.top_heading_idx
        %{<span class="progress">#{percent}%</span>}
    end
   
    def_service('progress_pages') do |args, text|
        idx = @deplate.output_index
        max = @deplate.top_heading_idx
        %{<span class="progress">#{idx}/#{max}</span>}
    end

    def_service('progress_first') do |args, text|
        idx = @deplate.output_index
        idx == 0 ? '1' : '0'
    end

    def_service('progress_last') do |args, text|
        idx = @deplate.output_index
        max = @deplate.top_heading_idx
        idx == max ? '1' : '0'
    end

    def_service('page_next_dest') do |args, text|
        hd = delta_heading(1)
        pagedest_relpath(hd)
    end
    
    def_service('page_next_title') do |args, text|
        hd = delta_heading(1)
        pagedest_relpath(hd)
    end
    
    def_service('page_prev_dest') do |args, text|
        hd = delta_heading(-1)
        pagedest_relpath(hd)
    end
    
    def_service('page_prev_title') do |args, text|
        hd = delta_heading(-1)
        hd && hd.description
    end
    
    def_service('page_home_dest') do |args, text|
        hd = @deplate.top_heading_by_idx(@deplate.home_index)
        pagedest_relpath(hd)
    end
    
    def_service('page_home_title') do |args, text|
        hd = @deplate.top_heading_by_idx(@deplate.home_index)
        (hd && hd.description) || @deplate.msg('Frontpage')
    end
   
    def htmlsite_tabbar(args, text, style, horizontal)
        if horizontal
            tagsl0 = 'table'
            tagsa0 = 'cellspacing="0"'
            tagsl1 = ['tr']
            tagsl2 = ['td']
            # tagsl1 = []
            # tagsl2 = ['span']
            width  = args['width']  || '100%'
            heigth = args['heigth'] || '20px'
        else
            tagsl0 = 'table'
            tagsa0 = 'cellspacing="0"'
            tagsl1 = []
            tagsl2 = ['tr', 'td']
            width  = args['width']  || '20px'
            heigth = args['heigth'] || '140px'
        end
        
        idx  = @deplate.output_index
        type = @variables['navBarType'] || :top
        urlp, prv = navbar_button_prev(nil, nil, idx, type, idx > @deplate.home_index)
        url, home = navbar_button_home(nil, nil, idx, type, idx > @deplate.home_index)
        urln, nxt = navbar_button_next(nil, nil, idx, type, idx < @deplate.top_heading_idx)

        tabbar = []
        tabbar << invoke_service('navigation_keys', {'next' => urln}) if args['nextKey']
        # tabbar << %{<#{tagsl0} width="#{width}" class="#{style}" summary="Navigation bar">} if tagsl0
        tabbar << %{<#{tagsl0} #{tagsa0} class="#{style}" summary="Navigation bar">} if tagsl0
        tabbar << htmlsite_tabbar_accum_tags(tagsl1, style, true)
      
        if !@variables['noTabBarButtons']
            s = "#{style}Buttons"
            o = htmlsite_tabbar_accum_tags(tagsl2, s, true)
            c = htmlsite_tabbar_accum_tags(tagsl2, s, false)
            if @variables['tabBarButtons']
                buttons = []
                for b in Deplate::Core.split_list(@variables['tabBarButtons'], ',', '; ')
                    case b
                    when 'home', 'h'
                        buttons << home
                    when 'next', 'n'
                        buttons << nxt
                    when 'prev', 'previous', 'p'
                        buttons << prv
                    end
                end
            else
                buttons = [prv, home, nxt]
            end
            buttons.compact!
            buttons.delete(%{&nbsp;})
            tabbar << [o, buttons.join(%{&nbsp;}), c].join
        end

        depth = args['depth']
        depth = depth ? depth.to_i : @deplate.options.split_level
        inactivedepth = args['depthInactive']
        inactivedepth = inactivedepth ? inactivedepth.to_i : depth
       
        tabbarsep   = @variables['tabBarSep'] || '|'
        tabbarsep   = /\s*#{Regexp.escape(tabbarsep)}\s*/
        tabbarextra = @variables['tabBar'] || ['[auto]']
        tabbarextra = tabbarextra.split(/\n/) if tabbarextra.kind_of?(String)
        if @variables['tabEqualWidths'] || @variables['equalTabs']
            tabsize = @deplate.top_heading_idx + tabbarextra.size
            tabsize = 100 / tabsize
            tabsize = %{ #{horizontal ? "width" : "heigth"}="#{tabsize}%"}
        else
            tabsize = nil
        end
        for e in tabbarextra
            if e == '[auto]'
                tabbar_auto_entries(tabbar, idx, style, depth, inactivedepth, tagsl2, tabsize)
            else
                title, url = e.split(tabbarsep)
                html = %{<a class="tabBarEntry" href="#{url}">#{title}</a>}
                tabbar << tabbar_entry(html, tagsl2, "#{style}Inactive", tabsize)
            end
        end
        
        if args['spacer']
            if horizontal
                spacer = %{<img width="1px" height="#{height}" src="%s" alt="" />} % args['spacer']
            else
                spacer = %{<img width="#{width}" height="1px" src="%s" alt="" />} % args['spacer']
            end
        else
            spacer = nil
        end
        
        if args['progressBar']
            if horizontal
                pb = invoke_service('progressBarVertical')
            else
                pb = invoke_service('progressBarHorizontal')
            end
            s = "#{style}Buttons"
            o = htmlsite_tabbar_accum_tags(tagsl2, s, true)
            c = htmlsite_tabbar_accum_tags(tagsl2, s, false)
            i = invoke_service('progressPercent')
            tabbar << [o, spacer, pb, i, c].compact.join
        end
       
        if (about = (args['about'] || @variables['tabBarAbout']))
            title = @deplate.msg('About this page')
            html  = %{<a class="tabBarAbout tabBarEntry" href="#{about}">#{title}</a>}
            tabbar << tabbar_entry(html, tagsl2, "#{style}Inactive #{style}About", tabsize)
        end

        tabbar << htmlsite_tabbar_accum_tags(tagsl1, style, false)
        tabbar << %{</#{tagsl0}>} if tagsl0
        return tabbar.compact.join("\n")
    end
    
    def htmlsite_progress_bar(args, horizontal)
        idx     = @deplate.output_index || 0
        percent = 100 * idx / @deplate.top_heading_idx
        anti    = 100 - percent
        all     = percent + anti
        if all != 100
            anti += 100 - all
        end
        height  = args['h'] || args['height'] || (horizontal ? '10pt'  : '100pt')
        width   = args['w'] || args['width']  || (horizontal ? '100pt' : '10pt')
        pb      = []
        # pb << %{<div class="progressBar">}
        pb << %{<table align="center" class="progressBar" width="#{width}" style="height:#{height}">}
        if horizontal
            pb << %{<tr>}
            pb << %{<td class="progressBarDone" width="#{percent}%" style="height:100%"></td>} unless percent == 0
            pb << %{<td class="progressBarToBeDone" width="#{100 - percent}%" style="height:100%"></td>} unless percent == 100
            pb << %{</tr>}
        else
            pb << %{<tr class="progressBarDone" width="100%" style="height:#{percent}%"></tr>} unless percent == 0
            pb << %{<tr class="progressBarToBeDone" width="100%" style="height:#{100 - percent}%"></tr>} unless percent == 100
        end
        pb << %{</table>}
        # pb << %{</div>}
        return pb.join
    end

    def delta_heading(delta)
        idx = @deplate.output_index
        if idx
            idx = idx.to_i + delta
            if idx >= 0
                return @deplate.top_heading_by_idx(idx)
            end
        end
        return nil
    end

    private
    def pagedest_relpath(hd)
        if hd
            curr = @deplate.top_heading_by_idx(@deplate.top_heading_idx)
            rv   = @deplate.relative_path(hd.output_location, File.dirname(curr.output_location))
            return rv
        end
    end
    
    def tabbar_auto_entries(tabbar, idx, style, depth, inactivedepth, tags, tabsize)
        if @variables['tabBarHomeName']
            hidx  = @deplate.home_index
            s     = idx == hidx ? "#{style}Active" : "#{style}Inactive"
            title = @variables['tabBarHomeName']
            file  = navbar_guess_file_name(hidx, idx, :navbar)
            tabbar << tabbar_entry(%{<a class="tabBarEntry" href="#{file}">#{title}</a>}, tags, s, tabsize)
        end

        @deplate.each_heading(depth) do |hd, title|
            t1 = @deplate.top_heading_by_idx(idx)
            t2 = hd.top_heading
            # if t1 == t2 or 
            #     (t1.kind_of?(Deplate::Element::Heading) and
            #      t2.kind_of?(Deplate::Element::Heading) and
            #      t1.level_heading[0] == t2.level_heading[0])
            if t1.level_heading[0] == t2.level_heading[0]
                s = ["#{style}Active #{style}Active-Level#{hd.level}"]
            elsif hd.level > inactivedepth
                next
            else
                s = ["#{style}Inactive #{style}Inactive-Level#{hd.level}"]
            end
            # s << "#{style}-Level#{hd.level}"

            # lstr = hd.level_as_string
            # lnr  = hd.top_heading_idx
            file = hd.output_file_name(:basename => true)
            file = escape_filename(file)
            if hd.level > @deplate.options.split_level
                anchor = hd.args[:id] || hd.label.first
                if anchor
                    file = [file, '#', anchor].join
                end
            end

            tabbar << tabbar_entry(
                                   %{<a class="tabBarEntry" href="#{file}">#{title}</a>}, 
                                   tags, 
                                   s.join(' '), 
                                   tabsize
                                  )
        end
    end

    def tabbar_entry(html, tags, html_class, tabsize)
        o = htmlsite_tabbar_accum_tags(tags, html_class, true,  tabsize)
        c = htmlsite_tabbar_accum_tags(tags, html_class, false, tabsize)
        [o, html, c].join
    end

    def htmlsite_tabbar_accum_tags(tags, htmlClass, open_tags, extra=nil)
        acc = []
        unless open_tags
            tags = tags.reverse
        end
        for t in tags
            if t
                if open_tags
                    t = %{<#{t}#{extra} class="#{htmlClass}">}
                else
                    t = %{</#{t}>}
                end
                acc << t
            end
        end
        if acc.empty?
            return nil
        else
            return acc.join
        end
    end
end

# class Deplate::Core
#     def formatter_initialize_htmlsite
#         @max_headings = nil
#     end
# end

# vim: ff=unix
