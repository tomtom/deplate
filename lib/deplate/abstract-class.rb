# encoding: ASCII
# DefAbstract.rb
# @Created:     18-Mär-2004.
# @Last Change: 2009-02-02.
# @Revision:    0.12
# 
# Description:
# From: http://groups.google.at/groups?hl=de&lr=&ie=UTF-8&oe=UTF-8&newwindow=1&selm=20030821221909.53f3274a.rpav%40mephle.com&rnum=38
# Von:Ryan Pavlik (rpav@mephle.com)
# Betrifft:Re: Class variables - a surprising result
# Newsgroups:comp.lang.ruby
# Datum:2003-08-21 22:20:26 PST 

class SubclassResponsibility < Exception; end

class Module
    def def_abstract(*args)
        for sym in args
            module_eval <<-CODE
            def #{sym}(*args)
                raise SubclassResponsibility
            end
            CODE
        end
    end #m:def_abstract
end #c:Module

# class B
    # def_abstract :foo, :bar
# end

