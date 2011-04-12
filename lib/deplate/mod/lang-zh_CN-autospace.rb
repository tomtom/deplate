# encoding: ASCII
# zh-cn-autospace.rb
# @Author:      Tom Link
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     01-Aug-2004.
# @Last Change: 2011-04-12.
# @Revision:    0.248

require 'deplate/zh_CN'

class Deplate::Formatter
    attr_reader :cjk_space, :cjk_nospace
    def hook_pre_setup_zh_cn_autospace
        @cjk_space   = ' '
        @cjk_nospace = ''
    end
end

class Deplate::Formatter::LaTeX
    def hook_pre_setup_zh_cn_autospace
        @cjk_space   = '~'
        @cjk_nospace = ' '
    end
end

class Deplate::Core
    @cjk_nonchars = '%c-%c' % [33, 0xA0]
    @cjk_rx_C = Regexp.new('[^%s]' % @cjk_nonchars)
    @cjk_rx_a = Regexp.new('[%s]' % @cjk_nonchars)
    class << self
        attr_reader :cjk_nonchars, :cjk_rx_a, :cjk_rx_C
    end

    def module_initialize_zh_cn_autospace
        class << self
            alias :zh_cn_autospace_join_particles :join_particles

            def join_particles(particles, container = nil)
                if self.class.respect_line_cont and (container.nil? or container.line_cont)
                    acc  = []
                    prev = ''
                    prev_cjk = false
                    particles.delete('')
                    particles.each_with_index do |e, i|
                        if e == ' '
                            enext = particles[i + 1]
                            if prev == ' ' or enext == ' '
                            elsif @formatter.cjk_smart_blanks and prev =~ Deplate::Core.cjk_rx_C and enext =~ Deplate::Core.cjk_rx_C
                                acc << @formatter.cjk_nospace
                            else
                                acc << @formatter.cjk_space
                            end
                        else
                            acc << e
                            prev = e
                        end
                    end
                    return acc.join
                else
                    zh_cn_autospace_join_particles(particles, container)
                end
            end
        end
    end

    def hook_pre_setup_zh_cn_particles
        register_particle(Deplate::Particle::Space)
        register_particle(Deplate::Particle::NonCJK)
    end

    def hook_late_require_zh_cn
        module_initialize_zh_cn_autospace
        call_methods_matching(@formatter, /^hook_pre_setup_zh_cn/)
    end
end

class Deplate::Element
    alias :zh_cn_autospace_join_lines :join_lines
    def join_lines(accum)
        if @deplate.class.respect_line_cont and self.line_cont
            accum.join(' ')
        else
            zh_cn_autospace_join_lines(accum)
        end
    end
end

class Deplate::Particle::Space < Deplate::Particle
    set_rx(/^ /)
    def setup
        @elt = ' '
    end
end

class Deplate::Particle::NonCJK < Deplate::Particle
    set_rx(/^([#{Deplate::Core.cjk_nonchars}])/o)
    @part = nil
    
    class << self
        attr_accessor :part
    end
    
    def setup
        @elt  = @match[0]
    end

    def process
        unless self.class.part
            particles = @@particles + @@particles_extended
            particles.delete(self.class)
            self.class.part = particles
        end
        @elt = @deplate.parse_with_particles(@container, @elt, self.class.part)
        @elt = @deplate.format_particles(@elt, @container)
    end
end

