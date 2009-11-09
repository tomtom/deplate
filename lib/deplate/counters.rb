# encoding: ASCII
# counters.rb
# @Author:      Tom Link (micathom AT gmail com)
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     31-Dez-2005.
# @Last Change: 2009-11-09.
# @Revision:    0.18

class Deplate::Counters
    def initialize(deplate)
        @deplate  = deplate
        @counters = {}
    end
    
    def def_counter(name, args={})
        parent_counter = args[:parent]
        if parent_counter
            parent, parent_level = parent_counter.split(/[.,:;@-_<> ]+/)
            parent_level = parent_level.to_i
            if parent_level > 0
                parent_level -= 1
            end
            pc = @counters[parent]
            if pc
                pc[:children] << {:name => name, :level => parent_level}
            else
                Deplate::Core.log(['Unknown counter', pc], :error)
            end
        else
            parent = nil
            parent_level = nil
        end
        init = args[:init] || [0]
        @counters[name] = {
            :value        => init.dup,
            :init         => init.dup,
            :children     => [],
            :parent       => parent,
            :parent_level => parent_level,
        }
    end

    def is_defined?(name)
        @counters.keys.include?(name)
    end
    
    def get(name, compound=false)
        c = @counters[name]
        if c
            if compound
                c
            else
                [get_parent(name), c[:value]].compact.flatten
            end
        else
            Deplate::Core.log(['Unknown counter', name], :error)
            nil
        end
    end
    
    def get_parent(name, compound=false)
        c = get(name, true)
        p = c[:parent]
        if p
            pl = c[:parent_level]
            v  = get(p, compound)
            if compound or !pl
                v
            else
                v[0..pl]
            end
        else
            nil
        end
    end
    
    def set(name, value, &etc)
        c = get(name, true)
        if c
            c[:value] = value
            if etc
                etc.call(c)
            end
        end
        self
    end

    def reset(name=nil, args={})
        if name
            c = get(name, true)
            if c
                c[:value] = c[:init].dup
                # i = c[:init].dup
                # l = args[:level]
                # if l
                #     v = c[:value]
                #     v = v[0..(l - 1)]
                # else
                #     v = i
                # end
                # set(name, v)
                c[:children].each do |cn, cl|
                    reset(cn, :level => l)
                end
            end
        else
            for name in @counters.keys
                reset(name)
            end
        end
    end
 
    # Increase a counter. Optional arguments:
    #     +:by+:: The value to add
    #     +:level+:: If the counter is hierarchical (an array), increase 
    #                    this level & reset all sublevels
    #     +:to_s+:: Return the counter as string
    def increase(name, args={})
        by = args[:by] || 1
        cc = get(name, true)
        if cc
            c = cc[:value]
            mx = c.size - 1
            lv = args[:level]
            lv = lv ? (lv.to_i - 1) : mx
            if lv < 0
                lv = 0
            end
            if lv < mx
                c = c[0..lv]
            end
            if lv > mx
                for i in (mx+1)..(lv-1)
                    c[i] = 0
                end
                c[lv] = by
            else
                c[lv] += by
            end
            set(name, c) do |c|
                c[:container] = args[:container]
            end
            cc[:children].each do |child|
                cn = child[:name]
                cl = child[:level]
                if cl >= lv
                    reset(cn)
                end
            end
            if args[:to_s]
                return value_to_string(get(name))
            else
                return self
            end
        else
            Deplate::Core.log(['Unknown counter', name], :error)
            return nil
        end
    end

    def get_s(name, args={})
        c = get(name)
        value_to_string(c, args) if c
    end

    def is_hierarchical?(name)
        c = get(name)
        c.kind_of?(Array)
    end
    
    def value_to_string(value, args={})
        delta = Deplate::Core.split_list(args['delta'] || '', '.', ',; ')
        if value.empty?
            delta.join('.')
        else
            value = value.dup
            depth = args['depth'].to_i - 1
            if depth >= 0
                value = value[0..depth]
            end
            delta.each_with_index do |d,i|
                value[i] = (value[i] || 0) + d.to_i
            end
            value.join('.')
        end
    end
end


class Deplate::Listings
    attr_accessor :listings

    def initialize(deplate)
        @deplate  = deplate
        @listings = {}
    end
    
    def def_listing(name, init=nil, props=nil)
        init  ||= []
        props ||= {}
        @listings[name] = {
            :value => init, 
            :init  => init,
            :props => props,
        }
    end

    def is_defined?(name)
        @listings.keys.include?(name)
    end
 
    def each
        @listings.each do |key, val|
            yield(key, val)
        end
    end
    
    def get(name, compound=false)
        c = @listings[name]
        if c
            if compound
                c
            else
                c[:value]
            end
        else
            Deplate::Core.log(['Unknown list', name], :error)
            nil
        end
    end
   
    def set(name, value, compound=false)
        if compound
            @listings[name] = value
        else
            @listings[name][:value] = value
        end
    end

    def get_prop(name, prop)
        c = @listings[name]
        if c
            c[:props][prop]
        else
            Deplate::Core.log(['Unknown list', name], :error)
            nil
        end
    end
    
    def push(name, value)
        c = get(name)
        if c
            c << value
        end
    end

    def reset(name=nil)
        if name
            c = get(name, true)
            if c
                set(name, c[:init])
            end
        else
            for name in @listings.keys
                reset(name)
            end
        end
    end
end

