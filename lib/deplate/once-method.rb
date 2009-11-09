# encoding: ASCII
# once-method.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     25-Mär-2005.
# @Last Change: 2009-11-09.
# @Revision:    0.25
#
# = Description
# Provide poor-man's once methods vor Module class.

class Module
    def once_method(*args)
        for sym in args
            module_eval <<-CODE
            alias :#{sym}__once :#{sym}
            private :#{sym}__once
            def #{sym}(*args)
                @@__once ||= {}
                if (rv = @@__once["#{sym}"])
                    return rv
                else
                    return (@@__once["#{sym}"] = #{sym}__once(*args))
                end
            end
            CODE
        end
    end
end

if __FILE__ == $0
    class TestOnce
        def foo(x)
            puts "This is foo being executed"
            return "bar" * x
        end
        once_method :foo
    end
    t = TestOnce.new
    p t.foo(2)
    p t.foo(3)
    p t.foo(3)
end

