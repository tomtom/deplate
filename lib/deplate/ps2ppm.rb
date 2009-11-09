#!/usr/bin/env ruby
# ps2ppm.rb
# @Author:      Peter Kleiweg
# @Created:     11-Nov-2004.
# @Last Change: 2008-12-15.
# @Revision:    0.104
#
# Ruby translation of the ps2ppm script that can be found 
# http://odur.let.rug.nl/~kleiweg/postscript/ps2ppm here. 
#
# Note that this is still very perlish.
# 
# The original perl script is by Peter Kleiweg.
# Kaspar Schiess (eule AT space.ch) converted this script to ruby.
# 
# This is a slightly modified and de-perlished version of his converted 
# script.
#

# require 'getopts'
# require 'pp'

module Ps2ppm
    @gsname   = "gs"
    # @gsname   = "gs.bat"
    @progname = "ps2pmm"
    @default = 'ppmraw'
       
    def syntax
        puts <<EOS

PostScript to Pixelmap(s) Converter
(C) P. Kleiweg 1996-1999

Usage: #{@progname} [-1ghot] [-f format] [-m margin] [-O orientation] [-r resolution] file[.[e]ps]

  -1: old PostScript Level 1 method (unsafe?)
  -f: format (default #{@default}), for listing type: gs -h
  -g: anti-alias graphics (try it)
  -h: this help
  -m: margin (default 0)
  -O: orientation (overrides %%Orientation comment)
      valid orientations are: Portrait Landscape Upside-Down Seascape
  -o: force overwrite
  -r: resolution (default 72)
  -t: anti-alias text (recommended)

EOS
        exit
    end
    module_function :syntax

    def run(file, opt={})
        syntax unless file

        level     = 2
        format    = @default
        margin    = 0
        overwrite = 0
        orient    = 'Portrait'
        res       = 72
        gab       = ''
        tab       = ''
        values    = []
        
        level     = true                    if opt['1']
        format    = opt['f']                if opt['f']
        margin    = Float(opt['m'])         if opt['m']
        overwrite = true                    if opt['o']
        res       = Integer(opt['r'])       if opt['r']
        gab       = '-dGraphicsAlphaBits=4' if opt['g']
        tab       = '-dTextAlphaBits=4'     if opt['t']

        case format
        when "jpeg"
            # values << "-dQFactor=1.0"
            values << "-dJPEGQ=100"
        end
        
        out_file1 = "#{file}.01.#{format}"
        
        # If you have problems with anti-aliasing, try uncommenting this:
        # if opt['g'] or opt['t']
        #     values << '-dRedValues=256 -dGreenValues=256 -dBlueValues=256 -dGrayValues=256'
        # end
        
        infile = file
        file = file.sub( /\.[eE]?[Pp][Ss]$/, '' )
        unless infile =~ /\.[eE]?[Pp][Ss]$/ 
            infile += '.ps'
        end
        
        if FileTest.file?(out_file1) && (! overwrite)
            raise "File exists: #{out_file1}";
        end
        
        found  = false
        level  = 0
        x1     = nil
        y1     = nil
        x2     = nil
        y2     = nil
        found  = nil
       
        postscript = nil
        File.open( infile, 'rb' ) do |io|
            postscript = io.readlines
        end
        postscript.each do |line|
            if level == 0 and line =~ /^%%BoundingBox:\s*(-?\d+)\s+(-?\d+)\s+(-?\d+)\s+(-?\d+)/
                x1 = Integer($1)
                y1 = Integer($2)
                x2 = Integer($3) 
                y2 = Integer($4)
                found = true 
            elsif level == 0 and line =~ /^%%Orientation:\s*(\S+)/
                o = $1
                if o =~ /^portrait$/i 
                    orient = 'Portrait';
                elsif o =~ /^landscape$/i
                    orient = 'Landscape'
                elsif o =~ /^upside-?down$/i
                    orient = 'Upside-Down'
                elsif o =~ /^seascape$/i
                    orient = 'Seascape'
                end
            elsif line =~ /^%%BeginDocument\b/
                level += 1
            elsif line =~ /^%%EndDocument\b/
                level -= 1
            end
        end
        found or raise "BoundingBox not found in #{file}.ps"

        if opt['O']
            case opt['O']
            when /^portrait/i
                orient = 'Portrait'
            when /^landscape$/i
                orient = 'Landscape'
            when /^upside-?down$/i
                orient = 'Upside-Down'
            when /^seascape$/i
                orient = 'Seascape'
            else 
                raise 'Illegal orientation'
            end
        end

        trans = ''

        if margin != 0
            trans << "#{margin} dup translate "
        end

        case orient
        when 'Portrait'
            w = x2 - x1
            h = y2 - y1
        when 'Landscape'
            w = y2 - y1
            h = x2 - x1
            t = -h
            trans << "-90 rotate #{t} 0 translate "
        when 'Upside-Down'
            w = x2 - x1
            h = y2 - y1
            ww = -w
            hh = -h
            trans << "180 rotate #{ww} #{hh} translate "
        when 'Seascape'
            w = y2 - y1
            h = x2 - x1
            t = -w
            trans << "90 rotate 0 #{t} translate "
        else
            raise "Unknown orientation: %s" % orient
        end

        w = ((2.0 * margin + w) * res / 72.0).to_i
        h = ((2.0 * margin + h) * res / 72.0).to_i

        x = -x1
        y = -y1
        trans << "#{x} #{y} translate"

        puts "#{file}.ps -> #{file}.%02d.#{format}"

        if defined?(Deplate::External.get_app)
            gsname = Deplate::External.get_app('gs', @gsname)
        else
            gsname = @gsname
        end
        cmdline = "#{gsname} -dDOINTERPOLATE #{values.join(" ")} #{gab} #{tab} -g#{w}x#{h} -r#{res} -sDEVICE=#{format} -sOutputFile=#{file}.%02d.#{format} -dNOPAUSE -"
        IO.popen(cmdline, 'w') do |gs|

            if level == 1
                gs.puts <<LEV1HEAD
/showpage {
  showpage
  #{trans}
  (.) print flush
} bind def
#{trans}
LEV1HEAD
            else
                gs.puts <<LEV2HEAD
<<
    /BeginPage {
        pop
        #{trans}
    }
    /EndPage {
        dup 0 eq {
            pop
            1 add 4 string cvs print ( ) print flush
            true
    } {
            1 eq
            exch pop
    } ifelse
    }
>> setpagedevice
LEV2HEAD
            end
            gs.puts postscript
            gs.puts "\nquit\n"
            return File.exist?(out_file1)
        end
    end
    module_function :run
end

# if __FILE__ == $0
#     file = ARGV.pop
#     getopts('1f:ghm:oO:r:t')
#     Ps2ppm.run(file, $OPT)
# end

