# encoding: ASCII
# mod-navbar1.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     14-Aug-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.81
# 
# Description:
# 
# Usage:
# 
# TODO:
# 
# CHANGES:
# 

class Deplate::Formatter::HTML_Site
    def prepare_navbar_png
        type = @deplate.variables['buttonsColour']
        fileformat = @deplate.variables['buttonsFileFormat'] || 'png'
        if type
            type = "-%s.%s" % [type, fileformat]
        else
            type = ".%s" % fileformat
        end
        hi = @deplate.variables['buttonsHighlight']
        if hi
            setup_highlight_image
        end
        [
            'prev',
            'home',
            'next',
            'go'
        ].each do |button|
            btn   = "navbar_#{button}"
            img   = "#{button}#{type}"
            hiimg = hi ? "hi-#{img}" : nil
            alt   = button.capitalize
            @deplate.variables["#{button}Button"] = include_image(nil, 
                                                                  # img_url(img), 
                                                                  img, 
                                                                  {'hi' => hiimg, 'alt' => alt, 'id' => btn, :raw => true},
                                                                  true
                                                                 )
        end
    end
end

