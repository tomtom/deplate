# encoding: ASCII
# define.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     19-Okt-2004.
# @Last Change: 2011-04-12.
# @Revision:    0.555

require 'deplate/commands'
require 'deplate/macros'

module Deplate::DefRegions; end
module Deplate::DefElements; end
module Deplate::DefParticles; end
module Deplate::DefCommand; end
module Deplate::DefMacro; end

# Description:
# 
# Usage:
# 
# TODO:
# 
# CHANGES:
# 
class Deplate::Define < Deplate::Region
    class << self
        def let_variables(deplate, args, &block)
            unset = []
            saved = {}
            begin
                args.each do |key, val|
                    if key.kind_of?(String)
                        opt = deplate.variables[key]
                        if opt
                            saved[key] = opt
                        else
                            unset << key
                        end
                        deplate.variables[key] = val
                    end
                end
                return block.call
            ensure
                unset.each do |key|
                    deplate.variables.delete(key)
                end
                saved.each do |key, val|
                    deplate.variables[key] = val
                end
            end
        end

        def check_arguments(mandatory, args, source)
            if mandatory
                diff = mandatory.split(/\s+/) - args.keys
                unless diff.empty?
                    Deplate::Core.log(['Missing arguments', diff], :error, source)
                end
            end
        end
    end
    
    def finish
        finish_accum
        define
        return nil
    end

    def valid_id?(id)
        if id =~ /\W/
            log(['Invalid ID', id], :error)
            return false
        else
            return true
        end
    end

    def valid_switch(arg, default)
        case arg
        when 'false', '0', 'F'
            'false'
        when 'true', '1', 'T'
            'true'
        else
            default
        end
    end
end

module Deplate::Define::TemplateExpander
    def use_template(template=@template, oargs={})
        # deplate = @deplate || oargs[:deplate]
        # args    = @args    || oargs[:args]
        # source  = @source  || oargs[:source]
        deplate = oargs[:deplate] || @deplate
        args    = oargs[:args] || @args
        source  = oargs[:source] || @source
        if args['noTemplate'] or deplate.variables['legacyDefine1']
            template
        else
            tmpl = Deplate::Template.new(:master    => deplate,
                                         :template  => template, 
                                         :source    => source, 
                                         :container => self)
            rv = nil
            Deplate::Define.let_variables(deplate, args) do
                rv = tmpl.fill_in(deplate, :source => source)
            end
            rv
        end
    end
end

# class Deplate::Define::Region < Deplate::Region::SecondOrder
class Deplate::Define::Region < Deplate::Region
    include Deplate::Define::TemplateExpander

    def finish
        finish_accum
        setup_template
        @args['@body'] = @accum.join("\n")
        deprecated_regnote
        Deplate::Define.check_arguments(@mandatory, @args, @source)
        @expected = Deplate::Element
        @elt      = []
        tpl = use_template
        Deplate::Define.let_variables(@deplate, @args) do
            # p "DBG DefineRegion: #{@deplate.options.counters.inspect}"
            @elt = @deplate.parsed_array_from_strings(tpl, @source.begin, @source.file)
        end
        unless @elt.empty?
            @elt.first.put_label(@label)
        end
        return @elt
    end
end

class Deplate::Regions::DefRegion < Deplate::Define
    register_as 'DefRegion'
    register_as 'DefineRegion'
    register_as 'Defr'
    
    def define
        id = deprecated_regnote('id')
        if valid_id?(id)
            # if @args['lineCont'] == false
                line_cont = 'set_line_cont false'
            # else
            #     line_cont = ''
            # end
            body = <<-EOR
                #{line_cont}
                def setup_template
                    @template  = #{@accum.inspect}
                    @mandatory = #{@args['args'].inspect}
                end
            EOR
            @args[:register] = true
            @args[:super]    = Deplate::Define::Region
            cls = Deplate::Cache.region(@deplate, body, @args)
        end
    end
end

class Deplate::Define::Element < Deplate::Element
    def finish
        m = self.class.match(@accum.join(' '))
        if m
            m.captures.each_with_index do |e, i|
                @args[(i + 1).to_s] = e
            end
            @expected = Deplate::Element
            tmpl = Deplate::Template.new(:template  => self.class.tpl,
                                         :source    => @source,
                                         :container => self)
            Deplate::Define.let_variables(@deplate, @args) do
                @accum = tmpl.fill_in(@deplate, :source => @source)
            end
            @accum.flatten!
            @accum.collect! {|l| l.split("\n")}
            @accum.flatten!
        else
            raise 'Internal error!'
        end
        @elt = @deplate.parsed_array_from_strings(@accum, @source.begin, @source.file)
        return @elt
    end
end

class Deplate::Regions::DefElement < Deplate::Define
    register_as 'DefElement'
    register_as 'DefineElement'
    register_as 'Defe'
    @@def_element_counter      = 0

    set_line_cont false
    
    def define
        rxs = deprecated_regnote('rx')
        if rxs
            @@def_element_counter += 1
            # template  = @accum.join("\n").gsub(/\'/, "\\\\\'")
            template  = @accum.join("\n")
            multiline = valid_switch(@args['multiline'], 'true')
            collapse  = valid_switch(@args['collapse'],  'false')
            begin
                # rx        = Regexp.new(rxs).source.gsub(/\//, '\\\\/')
                rx        = %r{^#{rxs}}
                body = <<-EOR
                    set_rx(#{rx.inspect})
                    class_attribute :tpl, #{template.inspect}
                    def setup
                        @multiliner = #{multiline}
                        @collapse   = #{collapse}
                        @accum      = [@match[0]]
                    end
                EOR
                @args[:register] = true
                @args[:super]    = Deplate::Define::Element
                cls = Deplate::Cache.element(@deplate, body, @args)
            rescue RegexpError => e
                Deplate::Core.log(["Invalid regular expression %s" % rxs, e], :error, @source)
            end
        end
    end
end

class Deplate::Define::Particle < Deplate::Particle
    def setup
        @match.captures.each_with_index do |e, i|
            @args[(i + 1).to_s] = e
        end
        @expected = Deplate::Particle
        tmpl = Deplate::Template.new(:template  => self.class.tpl,
                                     :source    => @source,
                                     :container => self)
        Deplate::Define.let_variables(@deplate, @args) do
            @elt = tmpl.fill_in(@deplate, :source => @source)
        end
        @elt = @deplate.parse(@container, @elt.join(' '))
    end

    def process
        @elt = @deplate.format_particles(@elt)
    end
end

class Deplate::Regions::DefParticle < Deplate::Define
    @@regions['DefParticle']    = self
    @@regions['DefineParticle'] = self
    @@regions['Defp']           = self
    @@def_particle_counter      = 0
    
    def define
        rs = deprecated_regnote('rx')
        if rs
            # template  = @accum.join("\n").gsub(/\'/, "\\\\\'")
            template  = @accum.join("\n")
            rx        = %r{^#{rs}}
            multiline = valid_switch(@args['multiline'], 'true')
            collapse  = valid_switch(@args['collapse'],  'false')
            # cls       = @deplate.formatter.retrieve_particle(rx.source, template)
            body = <<-EOR
                set_rx(#{rx.inspect})
                class_attribute :tpl, #{template.inspect}
            EOR
            @args[:register] = true
            @args[:super]    = Deplate::Define::Particle
            cls = Deplate::Cache.particle(deplate, body, @args)
        end
    end
end


class Deplate::Define::Command < Deplate::Command
    class << self
        include Deplate::Define::TemplateExpander

        def accumulate(source, array, deplate, text, match, args, cmd)
            Deplate::Core.log("%s: %s" % [cmd, text], :debug)
            template, mandatory = setup_template(text, deplate)
            args['@body'] = text
            Deplate::Define.check_arguments(mandatory, args, source)
            tpl = use_template(template, 
                               :deplate => deplate,
                               :args => args,
                               :source => source
                              )
            Deplate::Define.let_variables(deplate, args) do
                deplate.include_stringarray(tpl, array, source.begin, source.file)
            end
        end
    end
end


class Deplate::Regions::DefCommand < Deplate::Define
    register_as 'DefCommand'
    register_as 'DefCmd'
    register_as 'DefineCommand'
    register_as 'Defc'
    
    def define
        id = deprecated_regnote('id')
        if valid_id?(id)
            body = <<-EOR
                class << self
                    def setup_template(text, deplate)
                        [#{@accum.inspect}, #{@args['args'].inspect}]
                    end
                end
            EOR
            @args[:register] = true
            @args[:super]    = Deplate::Define::Command
            cls = Deplate::Cache.command(@deplate, body, @args)
        end
    end
end


class Deplate::Define::Macro < Deplate::Macro
    def setup(text)
        setup_template(text)
        @args['@body'] = text
        Deplate::Define.check_arguments(@mandatory, @args, @container.source)
        tmpl = Deplate::Template.new(:master    => @deplate,
                                     :template  => @template, 
                                     :source    => @source, 
                                     :container => self)
        rv = nil
        Deplate::Define.let_variables(@deplate, @args) do
            rv = tmpl.fill_in(@deplate)
        end
        @elt = @deplate.parse(self, rv.join(' '))
    end
end


class Deplate::Regions::DefMacro < Deplate::Define
    register_as 'DefMacro'
    register_as 'DefineMacro'
    register_as 'Defm'
    def define
        id = deprecated_regnote('id')
        if valid_id?(id)
            body = <<-EOR
                def setup_template(text)
                    @template  = #{@accum.join("\n").inspect}
                    @mandatory = #{@args['args'].inspect}
                    @macro_id  = #{id.inspect}
                end
            EOR
            @args[:register] = true
            @args[:super]    = Deplate::Define::Macro
            cls = Deplate::Cache.macro(@deplate, body, @args)
        end
    end
end



class Deplate::Regions::Native
    def expand_template
        deprecated_regnote
        @args['@body'] = @accum.join("\n")
        tmpl = Deplate::Template.new(:master => @deplate,
                                     :template => @template, 
                                     :source => @source, 
                                     :container => self)
        rv = nil
        Deplate::Define.let_variables(@deplate, @args) do
            rv = tmpl.fill_in(@deplate, :body => @args['@body'], :source => @source)
        end
        return rv
    end
end


class Deplate::Regions::DefRegionN < Deplate::Define
    register_as 'DefRegionN'
    register_as 'DefineRegionN'
    register_as 'Defrn'
    def define
        id = deprecated_regnote('id')
        if valid_id?(id)
            body = <<-EOR
                def finish
                    finish_accum
                    @template  = #{@accum.join("\n").inspect}
                    @mandatory = #{@args['args'].inspect}
                    @elt = [ expand_template ]
                    return self
                end
            EOR
            @args[:register] = true
            @args[:super]    = Deplate::Regions::Native
            cls = Deplate::Cache.region(@deplate, body, @args)
        end
    end
end


class Deplate::Define::CommandNative < Deplate::Command
    def expand_template
        @args['@body'] = @accum.join(' ')
        tmpl = Deplate::Template.new(:master => @deplate,
                                     :template => @template, 
                                     :source => @source, 
                                     :container => self)
        rv = nil
        Deplate::Define.let_variables(@deplate, @args) do
            rv = tmpl.fill_in(@deplate, :source => @source)
        end
        return rv
    end

    def format_special
        @elt
    end
end


class Deplate::Regions::DefCommandN < Deplate::Define
    register_as 'DefCommandN'
    register_as 'DefCmdN'
    register_as 'DefineCommandN'
    register_as 'Defcn'
    def define
        id = deprecated_regnote('id')
        if valid_id?(id)
            body = <<-EOR
                def finish
                    @template  = #{@accum.join("\n").inspect}
                    @mandatory = #{@args['args'].inspect}
                    @elt = [ expand_template ]
                    return self
                end
            EOR
            @args[:register] = true
            @args[:super]    = Deplate::Define::CommandNative
            cls = Deplate::Cache.command(@deplate, body, @args)
        end
    end
end


class Deplate::Define::MacroNative < Deplate::Macro
    def setup(text)
        setup_template
        @args['@body'] = text
        tmpl = Deplate::Template.new(:master => @deplate,
                                     :template => @template, 
                                     :source => @source, 
                                     :container => self)
        Deplate::Define.let_variables(@deplate, @args) do
            @text = tmpl.fill_in(@deplate, :source => @source)
        end
    end
end


class Deplate::Regions::DefMacroN < Deplate::Define
    register_as 'DefMacroN'
    register_as 'DefineMacroN'
    register_as 'Defmn'
    def define
        id = deprecated_regnote('id')
        if valid_id?(id)
            body = <<-EOR
                def setup_template
                    @template  = #{@accum.join(' ').inspect}
                    @mandatory = #{@args['args'].inspect}
                end
            EOR
            @args[:register] = true
            @args[:super]    = Deplate::Define::MacroNative
            cls = Deplate::Cache.macro(@deplate, body, @args)
        end
    end
end

