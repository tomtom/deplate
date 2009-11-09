# encoding: ASCII
# external.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     04-Sep-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.229

require "deplate/ps2ppm"

module Deplate::External
    @@apps = {}
    
    module_function
    def def_app(name, filename)
        @@apps[name] = filename
    end

    def get_app(name, default=nil)
        app = @@apps[name]
        unless app
            app = default || name
            if RUBY_PLATFORM =~ /mswin/ and app !~ /\.\w+$/
                app += '.exe'
            end
        end
        app
    end

    def log_popen(container, cmd)
        rv = []
        if container.deplate.allow_external
            container.log(["CWD", Dir.pwd])
            container.log(["Exec", cmd])
            begin
                IO.popen(cmd, "w+") do |io|
                    if block_given?
                        yield(io)
                    else
                        until io.eof
                            l = io.gets
                            rv << l.chomp
                            puts l unless Deplate::Core.quiet?
                        end
                    end
                end
            rescue StandardError => e
                container.log(["Error when running command", cmd, e], :error)
            end
        else
            container.log(["Disabled", cmd], :error)
            container.log("Use -X command line option to enable external commands", :newbie)
        end
        return rv.join("\n")
    end

    # The method assumes that the file should be created in the current 
    # directory, i.e., that the proper working directory was previously  
    # set
    def write_file(container, filename, &block)
        if container.deplate.allow_external
            File.open(filename, "w") {|io| block.call(io)}
        end
    end

    def latex(instance, texfile)
        log_popen(instance, "#{get_app('latex')} -interaction=nonstopmode #{texfile}")
    end

    def kpsewhich(instance, bibfile)
        bibfile = File.basename(bibfile)
        log_popen(instance, "#{get_app('kpsewhich')} #{bibfile}")
    end

    def dvi2ps(instance, dvifile, psfile, other_options=nil)
        log_popen(instance, "#{get_app('dvips')} -E -Z -D 300 #{other_options} -o #{psfile} #{dvifile}")
    end

    def dvi2png(instance, dvifile, outfile, other_options=nil)
        log_popen(instance, "#{get_app('dvipng')} -T tight -bg Transparent -D 120  #{other_options} -o #{outfile} #{dvifile}")
    end

    def ps2img(instance, device, psfile, outfile, args)
        # r = args["rx"] || instance.deplate.variables["ps2imgRes"] || 96
        r = args["rx"] || instance.deplate.variables["ps2imgRes"] || 120
        # r = args["rx"] || 140
        # case device
        # when "pdf"
        #     log_popen(instance, "#{get_app('ps2pdf'} #{psfile} #{outfile}")
        # else
        #     log_popen(instance, "#{get_app('ps2ppm'} -o -r #{r} -g -t -f #{device} #{psfile}")
            # log_popen(instance, "#{get_app('convert')} -antialias -density #{r}x#{r} #{psfile} #{outfile}")
            Ps2ppm.run(psfile, "o" => true, "r" => r, "g" => true, "t" => true, "f" => device)
        # end
    end

    def jave(instance, imgfile, args)
        variables = args[:deplate].variables
        cmd   = ["#{get_app('jave')} image2ascii #{imgfile}"]
        # p cmd
        alg   = args['ascii_algorithm'] || args['algorithm'] || 
            variables['ascii_algorithm'] || 'edge_detection'
        cmd << "algorithm=#{alg}"
        width = args['ascii_width'] || args['width'] || variables['ascii_width']
        if width =~ /^(\d+)%$/
            width = 80 * $1.to_i / 100
        elsif width =~ /^(\d+)cm$/
            width = $1.to_i / 2
        elsif width =~ /^(\d+)mm$/
            width = $1.to_i / 20
        elsif width =~ /^(\d+)px$/ or width.to_i > 120
            width = $1.to_i / 8
        elsif width =~ /^(\d+)pt$/
            width = $1.to_i / 8
        elsif width !~ /^(\d+)$/
            width = nil
        end
        cmd << "width=#{width}" if width
        log_popen(instance, cmd.join(' '))
    end
    
    def dot(instance, device, dotfile, outfile, command_line_args=[])
        c = command_line_args.join(' ')
        log_popen(instance, "#{get_app('dot')} -T#{device} -o#{outfile} #{c} #{dotfile}")
    end

    def neato(instance, device, dotfile, outfile, command_line_args=[])
        c = command_line_args.join(" ")
        log_popen(instance, "#{get_app('neato')} -T#{device} -o#{outfile} #{c} #{dotfile}")
    end

    def r(instance, rfile, outfile)
        c = "#{get_app('R')} CMD BATCH --slave --restore --no-save #{rfile} #{outfile}"
        log_popen(instance, c)
    end

    # return the bounding box as [bw, bh, bx, by]
    def image_dimension(filename)
        # `identify "#{filename}"`.scan(/(\d+)x(\d+)\+(\d+)\+(\d+)/).flatten
        rv = {}
        begin
            unless filename =~ /\.(pdf)$/
                output = `#{get_app('identify')} -verbose "#{filename}"`
                output.each_line do |line|
                    if line =~ /^\s*Geometry: /
                        bw = line.scan(/(\d+)x(\d+)(\+(\d+)\+(\d+))?/).flatten
                        bw.delete_at(2)
                        rv[:bw] = bw.collect {|x| x ? x.to_i : nil}
                    elsif line =~ /^\s*Resolution:/
                        res = line.scan(/(\d+)x(\d+)/).flatten
                        rv[:res] = res[0].to_i
                    end
                end
            end
            return rv
        rescue Exception => e
            Deplate::Core.log(["Running identify failed", filename, e], :error)
        end
        # Deplate::Core.log(['Cannot determine image dimensions', ifile], :error)
        return {}
    end

end

