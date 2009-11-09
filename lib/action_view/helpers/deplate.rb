# deplate.rb -- support for ActionPack's action_view
# @Author:      Tom Link (micathom AT gmail com)
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     13-Apr-2006.
# @Last Change: 2009-11-09.
# @Revision:    0.17

module ActionView
    module Helpers #:nodoc:
        module TextHelper
            begin
                require_library_or_gem 'deplate/deplate-string'
                unless defined?(DEPLATE_AUXBASEURL)
                    DEPLATE_AUXBASEURL = 'http://localhost:2500/'
                end
                o = DeplateString.deplate_options
                o.input_def = 'deplate-restricted'
                o.variables['headings']   = 'plain'
                o.variables['htmlAuxUrl'] = [DEPLATE_AUXBASEURL, 'files/%s'].join

                # Returns the text with all the deplate/viki codes turned into HTML-tags.
                # <i>This method is only available if deplate/deplate-string can be required</i>.
                def deplate(text, page_name=nil)
                    if text.blank?
            ''
                    else
                        out = DeplateString.new(text)
                        if page_name
                            pn = page_name.gsub(/[^a-zA-Z0-9_]/, '_')
                            out.deplate_options.variables['auxiliaryDir'] = 'public/files/%s' % pn
                            out.deplate_options.variables['mandatoryID']  = false
                        else
                            out.deplate_options.variables['auxiliaryDir'] = 'public/files'
                            out.deplate_options.variables['mandatoryID']  = true
                        end
                        out.to_html
                    end
                end
            rescue LoadError
                # We can't really help what's not there
            end
        end
    end
end

