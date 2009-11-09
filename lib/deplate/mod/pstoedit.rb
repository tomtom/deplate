# encoding: ASCII
# pstoedit.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     13-Apr-2005.
# @Last Change: 2009-11-09.
# @Revision:    0.79
#
# = Description
# Use pstoedit for converting postscript to images.
#
# = TODO
# * Run pstoedit only if the file has changed
# * Output from latex is sometimes ugly

module Deplate::External
    module_function
    def pstoedit(invoker, fps, fout, args)
        cmd = [get_app('pstoedit'), args, '-mergetext -adt -pti', fps, fout].join(' ')
        log_popen(invoker, cmd)
    end
end

class Deplate::Formatter
    def pstoedit_wrap(invoker, sfx, &block)
        case sfx
        when 'sfx'
            sfx = nil
        when 'jpeg'
            sfx = 'jpg'
        else
            log(["Unhandled suffix, let's see how it works", sfx], :anyway)
        end
        if sfx
            begin
                invoker.args['sfx'] = 'ps'
                block.call(invoker)
                id   = inlatex_id(invoker, true)
                fps  = id + '.ps'
                fout = [id, '.', sfx].join
                args = @deplate.variables['pstoeditArgs']
                @deplate.in_working_dir do
                    Deplate::External.pstoedit(invoker, fps, fout, args)
                end
                return fout
            ensure
                invoker.args['sfx'] = sfx
            end
        end
    end

    alias :pstoedit_inlatex :inlatex
    def inlatex(invoker)
        sfx = invoker.args['sfx'] || @deplate.variables['ltxSfx'] || inlatex_sfx
        invoker.elt = [pstoedit_wrap(invoker, sfx) {|i| pstoedit_inlatex(i)}]
    end
end

class Deplate::Regions::Img
    alias :img_re_pstoedit :img
    def img
        img  = nil
        sfx  = @args['sfx'] || @deplate.variables['imgSfx'] || 'png'
        fout = @deplate.formatter.pstoedit_wrap(self, sfx) {|i| img = img_re_pstoedit}
        if img
            img.elt = [fout]
        end
        img
    end
end

