# encoding: ASCII
# html-obfuscate-email.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     13-Jul-2005.
# @Last Change: 2009-11-09.
# @Revision:    0.37

class Deplate::Formatter::HTML
    alias :format_url_re_js_obfuscate_email :format_url
    
    def format_url(invoker, name, dest, anchor, literal=false)
        rv = format_url_re_js_obfuscate_email(invoker, name, dest, anchor, literal)
        if dest =~ /^mailto:/
            encoded = rv.unpack('C' * rv.size).join(',')
            dest0   = dest.sub(/^mailto:/, '')
            significant_name = (name != dest and name != dest0)
            if @deplate.variables['noObfuscatedNoscript']
                noscript = significant_name ? name : ''
            else
                at  = @deplate.variables['obfuscatedNoscriptAt'] || ' AT '
                dot = @deplate.variables['obfuscatedNoscriptDot'] || ' DOT '
                if significant_name
                    noscript = %{#{name} (#{dest})}
                else
                    noscript = name
                end
                noscript.gsub!(/(mailto:|[@.])/) do |t|
                    case t
                    when '@'
                        at
                    when '.'
                        dot
                    when 'mailto:'
                        ''
                    end
                end
            end
            js = %{<script type="text/javascript"><!--
document.write(String.fromCharCode(#{encoded}))
--></script><noscript>#{noscript}</noscript>}
        else
            rv
        end
    end
end

