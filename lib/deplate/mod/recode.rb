# encoding: ASCII
# recode.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     11-Apr-2005.
# @Last Change: 2009-11-09.
# @Revision:    0.59
#
# = Description
# Recode text on-the-fly using GNU +recode+. The source encoding is 
# taken from the +encoding+ variable (default: latin-1), the target 
# encoding is defined in the +recodeEncoding+ (default: utf-8) variable.
#
# This doesn't work properly yet. Until I find out how to make +recode+ 
# work on each line or how to use the recode libary via dl, we have to 
# start and stop +recode+ for each text bit.

class Deplate::Formatter
    # def hook_pre_go_recode
    #     recode_start
    # end
    
    def hook_post_go_recode
        recode_stop
    end

    def recode_start
        unless defined?(@recode_encoding_source)
            @recode_encoding_source = @deplate.variables['encoding'] || "latin-1"
            @recode_encoding_target = @deplate.variables['recodeEncoding'] || "utf-8"
            @deplate.variables['encoding'] = @recode_encoding_target
        end
        unless @recode_io
            @recode_io = IO.popen("#{Deplate::External.get_app('recode')} -d #@recode_encoding_source..#@recode_encoding_target", "w+")
            @recode_io.sync = true
        end
    end

    def recode_stop
        if @recode_io
            @recode_io.close
            @recode_io = nil
        end
    end
    
    def plain_text_recode(text)
        acc = []
        recode_start
        @recode_io.puts(text)
        @recode_io.close_write
        acc << @recode_io.read.chomp
        recode_stop
        acc.join
    end

end

