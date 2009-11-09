# encoding: ASCII
# cache.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     21-Aug-2005.
# @Last Change: 2009-11-09.
# @Revision:    0.49

# = Description
# This class provides a cache for dynamically generated classes.
class Deplate::Cache
    @@custom_particles = {}
    @@custom_macros    = {}
    @@custom_elements  = {}
    @@custom_regions   = {}
    @@custom_commands  = {}

    attr_reader :cls
 
    class << self
        def particle(deplate, body, args)
            register = args[:register]
            parent   = args[:super] || Deplate::Particle
            new(@@custom_particles, parent, deplate, body, args) do |cls|
                if register
                    args[:id] = body
                    deplate.input.register_particle(cls, args)
                end
            end
        end

        def element(deplate, body, args)
            register = args[:register]
            parent   = args[:super] || Deplate::Element
            new(@@custom_elements, parent, deplate, body, args) do |cls|
                if register
                    args[:id] = body
                    deplate.input.register_element(cls, args)
                end
            end
        end

        def command(deplate, body, args)
            register = args[:register]
            parent   = args[:super] || Deplate::Command
            new(@@custom_commands, parent, deplate, body, args) do |cls|
                if register
                    deplate.input.register_command(cls, args)
                end
            end
        end

        def region(deplate, body, args)
            register = args[:register]
            parent   = args[:super] || Deplate::Region
            new(@@custom_regions, parent, deplate, body, args) do |cls|
                if register
                    deplate.input.register_region(cls, args)
                end
            end
        end

        def macro(deplate, body, args)
            register = args[:register]
            parent   = args[:super] || Deplate::Region
            new(@@custom_macros, parent, deplate, body, args) do |cls|
                if register
                    deplate.input.register_macro(cls, args)
                end
            end
        end
    end
    
    def initialize(cache, super_class, deplate, body, args={})
        @deplate = deplate
        @cache   = cache
        specific = args[:specific]
        retrieve_particle(body, specific)
        unless @cls
            @cls = Class.new(super_class)
            if body.kind_of?(Proc)
                @cls.class_eval(&body)
            else
                @cls.class_eval(body)
            end
            store_particle(body, specific)
        end
        if @cls and block_given?
            yield(@cls)
        end
    end

    def retrieve_particle(body, specific=false)
        fmt       = get_formatter_name(specific)
        particles = @cache[fmt] ||= {}
        @cls = particles[body]
    end

    def store_particle(body, specific=false)
        fmt       = get_formatter_name(specific)
        particles = @cache[fmt] ||= {}
        particles[body] = @cls
    end

    def get_formatter_name(specific)
        return specific ? @deplate.formatter.formatter_name : :general
    end
end

