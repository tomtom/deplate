# encoding: ASCII
# numpara.rb -- add numbers to paragraphs
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     20-Aug-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.61
# 
# Description:
# 
# Usage:
# 
# TODO:
# 
# CHANGES:
# 

class Deplate::Formatter
    def module_initialize_numpara
        @numpara_done = []
        def_advice("numpara", :format_paragraph,
                  :wrap => Proc.new do |agent, rv, invoker, *rest|
                    unless invoker.args["noNum"] or @numpara_done.include?(invoker)
                        if defined?(@paragraph_number)
                            @paragraph_number += 1
                        else
                            @paragraph_number = 1
                        end
                        invoker.elt = numbered_paragraph(invoker.elt, @paragraph_number)
                        @numpara_done << invoker
                    end
                  end
                 )
    end

    def numbered_paragraph(text, number)
        return [text, plain_text("[%d]" % number)].join(" ")
    end
end

