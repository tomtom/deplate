# encoding: ASCII
# deplate-restricted.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     10-Mär-2005.
# @Last Change: 2009-11-09.
# @Revision:    0.47

# Deplate: Standard input
class Deplate::Input::DeplateRestricted < Deplate::Input
    self.myname = 'deplate-restricted'
    
    def initialize(deplate, args)
        remove_named_elements(args, :elements, Deplate::Element.elements, [])
        remove_named_elements(args, :commands, Deplate::Command.commands, [
                              Deplate::Command::INC,
                              # Deplate::Command::IMG, 
                              Deplate::Command::MODULE, 
                              Deplate::Command::WITH,
                              Deplate::Command::ABBREV,
        ])
        remove_named_elements(args, :regions, Deplate::Region.regions, [
                              Deplate::Regions::DefCommand,
                              Deplate::Regions::DefCommandN,
                              Deplate::Regions::DefRegion,
                              Deplate::Regions::DefRegionN,
                              Deplate::Regions::DefMacro,
                              Deplate::Regions::DefMacroN,
                              Deplate::Regions::Native,
                              Deplate::Regions::Img,
                              Deplate::Regions::R,
                              Deplate::Regions::Ruby,
        ])
        remove_named_elements(args, :macros, Deplate::Macro.macros, [
                              Deplate::Macro::Insert, 
                              # Deplate::Macro::Latex, 
                              # Deplate::Macro::Math, 
                              Deplate::Macro::Ruby,
        ])
        # remove_named_elements(args, :particles, Deplate::Particle.particles, [])
        # remove_named_elements(args, :particles_ext, Deplate::Particle.particles_ext, [])
        args[:onthefly_particles] ||= false
        super
    end
    
    def allow_set_variable(var)
        var && var[0..0] == '_'
    end
end

class Deplate::Core
    def input_initialize_deplate
        @options.input_class = Deplate::Input::DeplateRestricted
    end
end

