# encoding: ASCII
# variables.rb
# @Author:      Tom Link (micathom AT gmail com)
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     31-Dez-2005.
# @Last Change: 2010-10-10.
# @Revision:    0.108

require 'deplate/encoding'


class Deplate::Variables < Hash
    attr_accessor :deplate
    
    def initialize(deplate=nil)
        super()
        @deplate  = deplate
        @priority = false
    end
  
    def log(*args)
        Deplate::Core.log(*args)
    end

    def update(hash)
        for key, val in hash
            self[key] = val
        end
    end

    def set_value(name, value)
        begin
            @priority = true
            self[name] = value
        ensure
            @priority = false
        end
    end

    def []=(name, value)
        if name =~ /^[[:upper:]]+?([@\[]|$)/ and !@priority
            Deplate::Core.log(['No permisson', name, value], :error)
            return
        end
        if name.kind_of?(String) and (m = /^(\S+)\[([^\]]+)?\]$/.match(name))
            key   = real_name(m[1])
            field = m[2]
            var   = self[key]
            if !var
                if !field
                    self[key] = [value]
                elsif field =~ /^[0-9]$/
                    self[key] = []
                    self[key][field.to_i] = value
                else
                    self[key] = {field => value}
                end
            elsif var.kind_of?(Struct) || var.kind_of?(OpenStruct)
                var.send("#{field}=", value)
            elsif var.kind_of?(Hash)
                var[field] = value
            elsif var.kind_of?(Array)
                if !field
                    var << value
                elsif field =~ /^[0-9]+$/
                    field = field.to_i
                    var[field] = value
                else
                    Deplate::Core.log(['Wrong index', field, name, var.class], :error)
                end
            elsif var
                Deplate::Core.log(['Doc variable has wrong type', key, var.class], :error)
            end
        else
            rname = real_name(name)
            case rname
            when 'encoding'
                if RUBY_VERSION >= '1.9.1'
                    Encoding.default_external = Deplate::Encoding.ruby_enc_name(value)
                end
            end
            case operator(name)
            when '+'
                self[rname] = (self[rname].to_i + value.to_i).to_s
            when '&'
                if has_key?(rname)
                    self[rname] = "#{self[rname]}, #{value}"
                else
                    self[rname] = value
                end
            else
                super(rname, value)
            end
        end
    end

    def [](name)
        begin
            rname = real_name(name)
            if !name.kind_of?(String)
                return super
            elsif keys.include?(rname)
                return super(rname)
            # elsif name =~ /^no(\S+)$/ and (keys.include?($1) or keys.include?(name))
            #     return !super($1)
            elsif name =~ /^\S+\(.*?\)$/
                m = /^(\S+)\((.*?)?\)$/.match(name)
                if m
                    method = m[1]
                    args   = m[2]
                    args, text = @deplate.input.parse_args(args, nil, false)
                    rv = @deplate.formatter.invoke_service(method, args, text)
                    return rv
                else
                    Deplate::Core.log(['Malformed variable name', name], :error)
                end
            elsif name =~ /^:(\S+)$/
                n = $1
                if @deplate.is_allowed?(':', :logger => self)
                    return @deplate.options.send(n)
                end
            elsif (m = /^(\S+)\[(\S+)\]$/.match(name))
                key   = real_name(m[1])
                field = real_name(m[2])
                val   = self[key]
                return extract(val, key, field)
            elsif (m = /^(\S+)\.(\S+)$/.match(name))
                if @deplate.is_allowed?('.', :logger => self)
                    key  = real_name(m[1])
                    meth = m[2]
                    val  = self[key]
                    begin
                        return val.send(meth)
                    rescue Exception => e
                        log(['Invoking method failed', meth, val.class], :error)
                    end
                else
                    log(['No permission', name], :anyway)
                end
            end
        rescue Exception => e
            Deplate::Core.log(['Retrieving doc variable failed', name, e], :error)
        end
        return nil
    end

    def has_key?(name)
        super(real_name(name))
    end


    private

    def extract(val, key, field)
        if val.nil?
            Deplate::Core.log(['Unknown variable', key], :error)
        elsif val.kind_of?(Struct) || val.kind_of?(OpenStruct)
            return val.send(field)
        elsif val.kind_of?(Hash)
            return val[field]
        elsif val.kind_of?(Array)
            if field =~ /^[0-9]+$/
                field = field.to_i
                return val[field]
            else
                Deplate::Core.log(['Wrong index', field, name, val.class], :error)
            end
        elsif val.respond_to?('[]')
            return val[field]
        else
            Deplate::Core.log(['Variable has wrong type', key, val.class], :warning)
        end
    end

    def real_name(name)
        case name
        when String
            # if name[0..0] == '$'
            #     name = [1..-1]
            # end
            name = name.to_s
            if name =~ /[+&]$/
                name = name[0..-2]
            end
            if name.empty?
                nil
            else
                name
            end
        else
            name
        end
    end

    def operator(name)
        if name =~ /[+&]$/
            name[-1..-1]
        else
            nil
        end
    end

end

