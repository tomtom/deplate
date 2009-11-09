# encoding: ASCII
# linkmap.rb
# @Last Change: 2009-11-09.
# Author::      Jeff Barczewski (jeff barczewski at gmail com)
#               Minor modifications by Tom Link.
# License::     GPL (see http://www.gnu.org/licenses/gpl.txt)
# Created::     2007-09-27.
#
#
# Syntax for map (uses a region)
#
# #LinkMap << ---
#   key: url optional_title
# ---
#
# Syntax for using links in map (any of following)
# [[key]]
# [[key][link name]]
# [[key][link name]*] new window
# [[key]$] no follow rel
#
# or to embed raw URL using macro
# {ref: Example News}


# Map by current_source_id (each source) of keys to link values
class Deplate::LinkMap
    class << self
        def links(current_source_id)
            @links ||= {}
            @links[current_source_id] ||= {}
        end

        def set(current_source_id, label, href)
            links(current_source_id)[label] = href
        end

        def get(current_source_id, label)
            links(current_source_id)[label] || links(current_source_id)[:global]
        end
    end
end


# register links into a map for this source (each source has own map).
# Use link macro to access a link by key. The LinkMap can exist anywhere
# in the document, even at the end.
#
# #LinkMap <<---
# Example: http://www.example.com
# Example News: http://news.example.com
# ---
class Deplate::Regions::LinkMap < Deplate::Region
    register_as 'LinkMap'
    set_line_cont false

    def finish
        finish_accum
        sid = @args['global'] ? :global : @deplate.current_source.object_id
        log(['LinkMap', sid, @accum.inspect], :debug)
        @accum.each do |line|
            key, link = line.split(/:\s*/, 2).map {|e| e.strip}
            if key and link
                Deplate::LinkMap.set(sid, key, link)
            else
                log(['Malformed LinkMap entry', line.inspect], :error)
            end
        end
        return nil
    end

end


# access a link stored with LinkMap region
#
# {ref: Example News} == http://news.example.com/
class Deplate::Macro::RefLinkMap < Deplate::Macro::Ref
    register_as 'ref'

    def setup(text)
        @current_source_id = @deplate.current_source.object_id
        super
    end

    def process
        if @text
            ref = Deplate::LinkMap.get(@current_source_id, @text)
            if ref
                prefix = @args['prefix'] || @deplate.formatter.plain_text(' ', true)
                name = @args['p'] ? @deplate.formatter.plain_text(ref) : @deplate.parse_and_format(self, @args['name'] || @text)
                url  = format_particle(:format_url, self, name, ref, nil)
                # url  = @deplate.parse_and_format(self, ref)
                return [prefix, url].join
            end
        end
        super
    end
end


# access a mapped link using extended hyperlink
# [[link_key]]
# [[link_key][link name]]
class Deplate::HyperLink::ExtendedLinkMap < Deplate::HyperLink::Extended
    replace_particle Deplate::HyperLink::Extended

    def setup
        # save id for this source since it will change by the time we process
        @current_source_id = @deplate.current_source.object_id
        super
    end

    def process
        # use url from map if found for this source
        link_url = Deplate::LinkMap.get(@current_source_id, @dest)
        @dest = link_url if link_url
        super
    end
end


class Deplate::Core
    def hook_late_require_linkmap
        register_particle(Deplate::HyperLink::ExtendedLinkMap, :replace => Deplate::HyperLink::Extended)
        register_region(Deplate::Regions::LinkMap)
    end
end

