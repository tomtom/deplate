# encoding: ASCII
# mark-urls.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     16-Nov-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.44
# 
# Description:
# 
# Usage:
# 
# TODO:
# 
# CHANGES:
# 

class Deplate::Formatter
    def formatter_initialize_mark_urls
        def_advice('mark-external-urls', :format_url,
                  :wrap => Proc.new do |agent, rv, invoker, name, dest, *args|
                    if dest =~ Deplate::HyperLink::Url.rx
                        if dest =~ /^mailto:/
                            icon = @variables['mailtoIcon'] || 'mailto.png'
                            invoker.args['alt'] ||= 'e-mail'
                        else
                            icon = @variables['urlIcon'] || 'url.png'
                            # invoker.args['alt'] ||= 'url'
                        end
                        args = {'style' => 'remote'}
                        img  = format_particle(:include_image, invoker, icon, args, true)
                        if @variables['markerInFrontOfURL']
                            img + rv
                        else
                            rv + img
                        end
                    else
                        rv
                    end
                  end
                 )
    end
end

