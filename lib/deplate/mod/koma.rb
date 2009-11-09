# encoding: ASCII
# mod-koma.rb -- Module: use Koma-Script and friends as LaTeX class
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     07-Mai-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.113
# 
# Description:
# 
# Usage:
# 
# TODO:
# 
# CHANGES:
# 

class Deplate::Formatter::LaTeX
    self.latexDocClass = "scrartcl"

    # def hook_pre_prepare_koma
    #     push_class_option('tablecaptionabove')
    # end
    
    def format_header_or_footer(invoker, left, center, right, linesep=nil)
        args = invoker.args
        elt = invoker.elt
        if elt.size > 1
            format_header_or_footer_error(elt)
        end
        catch :error do
            e = elt[0]
            if e.kind_of?(Deplate::Element::Paragraph)
                l = c = r = nil
                ee = wrap_text(e.elt)
                if args["center"]
                    c = ee
                elsif args["right"]
                    r = ee
                else
                    l = ee
                end
            elsif e.kind_of?(Deplate::Element::Table)
                log("Only the header's first row will be used", :error) if e.elt.size > 1
                l, c, r = e.elt[0].cols.collect {|c| c.cell}
            else
                format_header_or_footer_error(elt)
            end

            output(invoker, "\\%s{%s}" % [left, l])   if l and !l.empty?
            output(invoker, "\\%s{%s}" % [center, c]) if c and !c.empty?
            output(invoker, "\\%s{%s}" % [right, r])  if r and !r.empty?
            ls = args["linesep"] || args["sep"]
            if ls
                if ls == true
                    ls = "0.4pt"
                elsif ls =~ /^[0-9.]+$/
                    ls = "%dpt" % ls
                end
                output(invoker, "\\%s{%s}" % [linesep, ls])
            end
        end
    end

    def format_header_or_footer_error(elt)
        elts = "%s %s" % [elt.size, elt.collect {|e| e.class}.join(", ")]
        log(["Header must contain only 1 element (a paragraph or a table)", elts], :error)
    end

    def format_header(invoker)
        type = invoker.doc_type(:pre)
        slot = invoker.doc_slot(:body_pre)
        unless @deplate.variables['__pagestyle_initialized']
            add_package("scrpage2")
            type, cslot, slot = format_header_or_footer_slots(type, slot)
            output_at(type, cslot, "", %{\\clearscrheadfoot{}})
            output_at(type, slot, %{\\pagestyle{scrheadings}}, "")
            @deplate.variables['__pagestyle_initialized'] = true
        end
        format_header_or_footer(invoker, "ihead", "chead", "ohead", "setheadsepline")
    end

    def format_footer(invoker)
        type = invoker.doc_type(:pre)
        slot = invoker.doc_slot(:body_pre)
        unless @deplate.variables['__pagestyle_initialized']
            add_package("scrpage2")
            type, cslot, slot = format_header_or_footer_slots(type, slot)
            output_at(type, cslot, "", %{\\clearscrheadfoot{}})
            output_at(type, slot, %{\\pagestyle{scrheadings}}, "")
            @deplate.variables['__pagestyle_initialized'] = true
        end
        format_header_or_footer(invoker, "ifoot", "cfoot", "ofoot", "setfootsepline")
    end

    def format_header_or_footer_slots(type, slot)
        if slot == :body_pre and type == :pre
            return [type, :prematter_end, slot]
        else
            return [type, slot, slot]
        end
    end
    
    def format_pagenumber(invoker)
        return "\\pagemark{}"
    end
end

# vim: ff=unix
