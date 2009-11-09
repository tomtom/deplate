# encoding: ASCII
# textstyles-warn-single.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     03-Okt-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.12

class Deplate::Particle::DeprecatedTextStyleMarkup < Deplate::DeprecatedParticle
    def get_text(match)
        match[2]
    end
    def get_prepost(match)
        [[match[1]], [match[4]]]
    end
end

class Deplate::Particle::EmphasizeDeprecated < Deplate::Particle::DeprecatedTextStyleMarkup
    register_particle
    set_rx(/^(\*\*)(.+?)(\*\*)/)
end

class Deplate::Particle::CodeDeprecated < Deplate::Particle::DeprecatedTextStyleMarkup
    register_particle
    set_rx(/^(==)(.+?)(==)/)
end

class Deplate::Particle::EmphasizeSingleDeprecated < Deplate::Particle::DeprecatedTextStyleMarkup
    register_particle
    set_rx(/^(\*)((\w|\\[*\s])+?)(\*)/)
end

class Deplate::Particle::CodeSingleDeprecated < Deplate::Particle::DeprecatedTextStyleMarkup
    register_particle
    set_rx(/^(=)((\w|\\[=\s])+?)(=)/)
end

