# encoding: ASCII
# inlatex-compound.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     07-Apr-2005.
# @Last Change: 2009-11-09.
# @Revision:    0.52
#
# = Description
# This module changes the way deplate processes inline latex fragments. 
# By default, deplate converts each fragment for its own. When using 
# this module, the latex fragments are collected in one file, are 
# translated to dvi and ps, and then separated to bitmap files.

class Deplate::Formatter
    alias :inlatex_compound :inlatex
    
    # Process inline latex
    def inlatex(invoker)
        unless defined?(@inlatex_body)
            @inlatex_body      = []
            @inlatex_container = []
            @inlatex_suffix    = nil
        end
        @inlatex_body << invoker.accum
        @inlatex_body << %{\\newpage{}}
        # @inlatex_body << %{\\clearpage{}}
        rv = @inlatex_container.size
        @inlatex_container << invoker
        @inlatex_suffix ||= invoker.args['sfx']
        rv
    end

    def hook_pre_process_inlatex
        pseudo = Deplate::PseudoContainer.new(@deplate,
                                              :accum => @inlatex_body,
                                              :args => {'sfx' => @inlatex_suffix}
                                             )
        inlatex_compound(pseudo)
        fnames = pseudo.elt
        if fnames.size != @inlatex_container.size
            log(['Unexpected number of output files',
                "#{fnames.size} (#{@inlatex_container.size})"], :error)
        end
        if @inlatex_container.kind_of?(Array) and fnames.kind_of?(Array)
            @inlatex_container.each_with_index {|o, i| o.elt = [fnames[i]]}
        end
    end

    def inlatex_process_latex(invoker, ftex, faux, flog)
        latex2dvi(invoker, ftex, faux, flog)
    end

    def inlatex_process_dvi(invoker, fdvi, fps)
        dvi2ps(invoker, fdvi, fps, '-i -S 1')
    end

    def inlatex_process_ps(invoker, device, fps, fout, args)
        fin = File.basename(fps, '.*')
        for fps in Dir["#{fin}.[0-9][0-9][0-9]"]
            File.rename(fps, "#{fps}.ps")
            ps2img(invoker, device, fps, fout, args)
        end
    end
end

