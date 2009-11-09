# encoding: ASCII
# skeletons.rb
# @Author:      Tom Link (micathom AT gmail com)
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     28-Apr-2006.
# @Last Change: 2009-11-09.
# @Revision:    0.152

# Skeletons: 
class Deplate::SkeletonExpander <  Deplate::CommonObject
    def initialize(deplate)
        @deplate        = deplate
        @formatter      = deplate.formatter
        @formatter_name = @formatter.class.myname
        @max_iteration  = 5
        @skeletons      = deplate.options.skeletons
        @skeletons_tmpl = {}
        @skel_ids       = {}
        @skel_names     = @skeletons.collect {|n| Regexp.escape(n)}.join('|')
        @rx = Deplate::Rx.builder("\\{\\{((#@skel_names)\\b(?>\\\\\\{|\\\\\\}|\\\\\\\\|[^{}]+?|{#})*)\\}\\}|^[[:blank:]]+", 
                                  Regexp::MULTILINE, 5, false)
        srand(Time.now.to_i)
    end

    def require_skeleton(name, source=nil)
        skels = @skeletons_tmpl[@formatter_name] ||= {}
        # names = @deplate.formatter_family_members.collect {|f| "#{name}.#{f}"}
        # names = @deplate.formatter.formatter_family_members.collect {|f| "#{name}.#{f}"}
        # names << name
        # names.each do |name|
            t = skels[name] ||= load_skeleton(name)
            return t if t
        # end
        Deplate::Core.log(['Unknown skeleton', name], :error, source)
    end

    def load_skeleton(name)
        # tmpl = @deplate.skeletons[name]
        tmpl = @deplate.find_in_lib(name, :pwd => true)
        if tmpl and File.exist?(tmpl)
            t = File.open(tmpl) {|io| io.read}
            return t
        end
        return nil
    end

    def expand(string, source=nil, iterations=@max_iteration)
        if string.empty?
            return string
        end
        expanded = false
        indent   = ''
        string.gsub!(@rx) do |s|
            text = $1
            if text
                expansion = expand_skeleton(text, indent, source)
                if expansion
                    expanded ||= true
                    expansion
                else
                    text
                end
            else
                indent = s
            end
        end
        if expanded and iterations > 0
            return expand(string, source, iterations - 1)
        else
            return string
        end
    end
    
    def split_name_args(string)
        m    = Regexp.new("^(#@skel_names)\s*").match(string)
        name = m[1]
        args = m.post_match.strip
        if args
            args = Deplate::Core.remove_backslashes(args)
            args, body = @deplate.input.parse_args(args)
            args['@body'] = body
        else
            args = {}
        end
        return name, args
    end
    
    def expand_skeleton(string, indent='', source=nil)
        name, args = split_name_args(string)
        if @skeletons.include?(name)
            special = "skeleton_#{name}"
            text    = if respond_to?(special)
                          send(special, args)
                      else
                          skeleton = require_skeleton(name, source)
                          if skeleton
                              tmpl  = Deplate::Template.new(:template => skeleton, 
                                                            :source   => source)
                              accum = Deplate::Define.let_variables(@deplate, args) do
                                  tmpl.fill_in(@deplate, :source => source)
                              end
                              accum.flatten!
                              accum.join("\n")
                          else
                              nil
                          end
                      end
            if text
                return @formatter.indent_text(text, :hanging => true, :indenttail => indent)
            end
        end
        return nil
    end

    def skeleton_id(args)
        name = args['name'] || args['id'] || args['@body']
        sep  = '_' * (4 + rand(4))
        # rid  = Time.now.to_f
        rid  = '%x' % rand.to_s[2..-1].to_i
        @skel_ids[name] ||= [sep, name, rid, sep].join('_')
        return @skel_ids[name]
    end
end

