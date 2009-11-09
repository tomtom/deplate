# encoding: ASCII
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     26-Feb-2005.
# @Last Change: 2009-11-09.
# @Revision:    0.118
# 
# = Description
# This module provides a specialized syntax highlighter using 
# http://coderay.rubychan.de/

require 'coderay'

class Deplate::Regions::Code
    langs = ['ruby', 'c', 'delphi', 'pascal', 'html', 'rhtml', 'xhtml']
    add_highlighter(langs, 'html',         :coderay_to_html)
    add_highlighter(langs, 'htmlslides',   :coderay_to_html)
    add_highlighter(langs, 'htmlsite',     :coderay_to_html)
    add_highlighter(langs, 'html-snippet', :coderay_to_html)
    add_highlighter(langs, 'xhtml10t',     :coderay_to_html)
    add_highlighter(langs, 'xhtml11m',     :coderay_to_html)
    add_highlighter(langs, 'php',          :coderay_to_html)
    add_highlighter(langs, 'phpsite',      :coderay_to_html)
    highlighter_option(:coderay_to_html, :no_cache => true)
    
    def coderay_to_html(syntax, style, text)
        unless @deplate.allow_external
            return
        end
        tokens = CodeRay.scan text, syntax.intern
        args = {}
        # args[:css] = :class
        if @args['lineNumers'] or @deplate.variables['codeLineNumbers']
            args[:line_numbers] = :table
        end
        begin
            rv = [tokens.div(args)]
            return rv
        rescue Exception => e
            log(['Error in module', 'code-coderay', e], :error)
        end
        return nil
    end
end

