# encoding: ASCII
# textstyles1.rb -- Re-enable text styles markup prior to version 0.6
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     03-Okt-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.16

class Deplate::Particle::Emphasize < Deplate::SimpleParticle
    @rx = /^\*\*(.+?)\*\*/
end

class Deplate::Particle::Code < Deplate::Particle
    @rx = /^==(.+?)==/
    class << self
        def markup(text)
            %{==%s==} % text.gsub("'", "\\\\'")
        end
    end
end

class Deplate::Particle::EmphasizeSingle < Deplate::Particle::Emphasize
    @@particles << self
    @rx = /^\*((\w|\\[*\s])+?)\*/
end

class Deplate::Particle::CodeSingle < Deplate::Particle::Code
    @@particles << self
    @rx = /^=((\w|\\[=\s])+?)=/
end

class Deplate::Macro::Emphasize < Deplate::Macro::FormattedText
    @@macros.delete("_")
    @@macros["*"] = self
end

class Deplate::Macro::Code
    @@macros.delete("'")
    @@macros["="] = self
end

