# encoding: ASCII
# zh-cn.rb
# @Author:      Tom Link
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     01-Aug-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.171

require 'deplate/zh_CN'

class Deplate::Element
    alias join_lines_re_zh_cn join_lines
    def join_lines(accum)
        if @deplate.formatter.matches?('latex')
            return accum.join
        else
            return join_lines_re_zh_cn(accum)
        end
    end
end

class Deplate::Particle::SwallowedSpace < Deplate::Particle
    set_rx(/^ +/)

    def setup
        @elt = @deplate.formatter.cjk_smart_blanks ? '' : ' '
    end
end

class Deplate::Particle::Space < Deplate::Particle
    set_rx(/^~/)

    def setup
        @elt = '~'
    end
    
    def process
        if @deplate.formatter.matches?('latex')
            super
        else
            @elt = ' '
        end
    end
end

class Deplate::Core
    def hook_post_input_initialize_zh_cn_particles
        register_particle(Deplate::Particle::Space)
        register_particle(Deplate::Particle::SwallowedSpace)
    end
    
    def hook_late_require_zh_cn
        call_methods_matching(self, /^hook_post_input_initialize_zh_cn_/)
        call_methods_matching(@formatter, /^hook_pre_setup_zh_cn/)
    end
end

