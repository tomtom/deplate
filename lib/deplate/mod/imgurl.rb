# encoding: ASCII
# imgurl.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     05-Mai-2005.
# @Last Change: 2009-11-09.
# @Revision:    0.32
#
# = Description
# Insert URLs to images as image

require 'deplate/wiki-markup'

# Insert URLs to images as image
class Deplate::HyperLink::ImgUrl < Deplate::Input::Wiki::ImgUrl
    insert_particle_before(Deplate::HyperLink::Url)
    set_rx(/^((file|https?|mailto|ftps?|www):(\S+?)\.(png|jpg|jpeg|gif|bmp))/)
end

class Deplate::HyperLink::Extended
    alias :process_re_imgurl :process
    def process
        if @dest =~ /\.(png|jpg|jpeg|gif|bmp)$/
            @elt = @deplate.formatter.include_image(self, encode_path(@dest), @args, true)
        else
            process_re_imgurl
        end
    end
end

