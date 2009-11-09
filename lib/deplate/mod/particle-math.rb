# encoding: ASCII
# particle-math.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     25-Mär-2005.
# @Last Change: 2009-11-09.
# @Revision:    0.33
#
# = Description
# This provides a math markup as known from LaTeX:
# $\latexmarkup$
#
# Support block markup for formulas via: $$\latexmarkup$$


class Deplate::Particle::Math < Deplate::Particle
    register_particle
    set_rx(/^(\$\$?)(\S.*?)(\$\$?)/)

    def setup
        @proxy = Deplate::Macro::Math.new(@deplate, @container, @context, {'block' => is_block?}, @alt, get_text)
    end
    
    def process
        @elt = @proxy.process
    end

    def get_text
        return @match[2]
    end

    def is_block?
        return @match[1] == '$$'
    end
end


class Deplate::Core
    def hook_late_require_particle_math
        register_particle(Deplate::Particle::Math)
    end
end

