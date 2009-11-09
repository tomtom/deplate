# encoding: ASCII
# fmt-xhtml.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     03-Aug-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.49

require "deplate/fmt/html"

class Deplate::Formatter::XHTML10transitional <  Deplate::Formatter::HTML
    self.myname   = "xhtml10t"
    self.rx     = /x?html?/i
    self.suffix = ".xhtml"

    def head_doctype
        return %Q{<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
            "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">}
    end
    
    def html_lang(stripped=false)
    end

    def html_def
        acc = [%{xmlns="http://www.w3.org/1999/xhtml"}]
        lang = @deplate.options.messages.prop('lang', self)
        if lang
            acc << %{lang="#{lang}"} << %{xml:lang="#{lang}"}
        end
        "<html #{acc.join(" ")}>"
    end
    
    def head_meta_tag(text)
        return %Q{<meta #{text} />}
    end
    
    def head_link_tag(text)
        return %Q{<link #{text} />}
    end

    def include_image_svg(invoker, file, args, inline=false)
        if args['include']

            svg = File.read(file)
            svg.sub!(/^.*?<\?xml .*?\?>[^<]*/, '')
            svg.sub!(/^<!DOCTYPE .*?>[^<]*/, '')
            return svg

        else

            acc  = ['type="image/svg+xml"']

            file = args['file'] if args['file']
            file = img_url(use_image_filename(file, args))
            acc << %{data="#{file}"}

            w = args['w'] || args['width']
            acc << %{width="#{w}"} if w
            h = args['h'] || args['heigth']
            acc << %{height="#{h}"} if h

            # b = args['border'] || '0'
            # acc << %{border="#{b}"}

            # # f = file[0..-(File.extname(file).size + 1)]
            # alt = args['alt']
            # if alt
            #     alt.gsub!(/[\\"&<>]/) do |s|
            #         case s
            #         when '\\'
            #             ''
            #         else
            #             plain_text(s).gsub(/\\([0-9&`'+])/, '\\1')
            #         end
            #     end
            # else
            #     alt = File.basename(file, '.*')
            # end
            # acc << %{alt="#{alt}"}

            style = args['style']
            if style
                style = Deplate::Core.split_list(style, ',', '; ', invoker.source)
            else
                style = []
            end
            style << (inline ? 'inline' : 'figure')
            acc << %{class="#{class_attr(style)}"}

            img_id = args['id']
            unless img_id
                fbase  = Deplate::Core.clean_name(File.basename(fbase || 'imgid'))
                img_id = @deplate.auto_numbered(fbase, :inc => 1, :fmt => %{#{fbase}_%s})
            end
            acc << %{id="#{img_id}" name="#{img_id}"}

            # hi = args['hi']
            # if hi
            #     case hi
            #     when String
            #         hi_img = img_url(use_image_filename(hi, args))
            #     else
            #         hi_img = [File.dirname(file), %{hi-#{File.basename(file)}}]
            #         hi_img = File.join(hi_img.compact)
            #     end
            #     
            #     setup_highlight_image
            #     acc << %{onMouseover="HighlightImage('%s', '%s')" onMouseout="HighlightImage('%s', '%s')"} % [
            #         img_id, img_url(hi_img, args), 
            #         img_id, file
            #     ]
            # end

            return %{<object #{acc.join(' ')} ></object>}

        end
    end

end

