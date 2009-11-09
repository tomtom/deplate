# encoding: ASCII
#!/usr/bin/env ruby
# entities.rb
# @Last Change: 2009-11-09.
# Author::      Tom Link (micathom AT gmail com)
# License::     GPL (see http://www.gnu.org/licenses/gpl.txt)
# Created::     2007-11-28.

require 'singleton'


class Deplate::EntityDecode
    include Singleton
    class << self
        def with_deplate(deplate)
            ent = self.instance
            deplate.formatter.setup_entities
            ent.deplate = deplate
            ent
        end
    end

    attr_accessor :deplate

    def char_by_number(number)
        @deplate.formatter.entities_table.each do |char, named, numbered|
            if numbered == number
                return char
            end
        end
        return number
    end

    
    def char_by_name(name)
        @deplate.formatter.entities_table.each do |char, named, numbered|
            if named == name
                return char
            end
        end
        return name
    end

end


class Deplate::Particle::EntityDecode < Deplate::Particle
    register_particle
    set_rx(/^&#\d+;/)
    def_get :text, 0

    def process
        @elt = Deplate::EntityDecode.with_deplate(@deplate).char_by_number(get_text)
    end

end


class Deplate::Particle::NamedEntityDecode < Deplate::Particle
    register_particle
    set_rx(/^&\w+?;/)
    def_get :text, 0

    def process
        @elt = Deplate::EntityDecode.with_deplate(@deplate).char_by_name(get_text)
    end

end


# Local Variables:
# revisionRx: REVISION\s\+=\s\+\'
# End:
