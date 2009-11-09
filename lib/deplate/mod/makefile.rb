# encoding: ASCII
# makefile.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     28-Aug-2005.
# @Last Change: 2009-11-09.
# @Revision:    0.212
#
# = Description
# Create a standard makefile.

# require ''

class Deplate::Core
    def deplate_initialize_makefile
        options      = @@command_line_args
        for f in @options.files.reverse
            if options.last == f
                options.pop
            else
                log(['Internal error', 'Makefile', @@command_line_args], :error)
                options = []
                break
            end
        end
        unless options.empty?
            options.each_with_index do |e,i|
                if e == 'makefile'
                    o = options[i - 1]
                    if o == '-m' or o == '--module'
                        options.slice!(i-1 .. i)
                        break
                    end
                end
            end
        end

        base, *files = @options.files
        base0        = File.basename(base, '.*')
        suffix       = clean_makefile_name(File.extname(base))

        if @variables['genericViewer']
            genericViewer = @variables['genericViewer']
        elsif ENV['genericViewer']
            genericViewer = ENV['genericViewer']
        elsif ENV['GNOME_DESKTOP_SESSION_ID']
            genericViewer = 'gnome-open'
        elsif ENV['KDEDIR']
            genericViewer = 'kfmclient'
        elsif ENV['CYGWIN'] || ENV['CYGWIN_PATH'] || ENV['CYGWIN_HOME']
            genericViewer = 'cygstart'
        else
            genericViewer = 'echo Not supported: genericViewer '
        end

        makefile = <<MAKEFILE
include Makefile.config

all: dbk html pdf tex text man

dvi: ${BASE}.dvi
dbk: ${BASE}.dbk
html: ${BASE}.html
xhtml: ${BASE}.xhtml
pdf:
	make FILE="${FILE}" DFLAGS="${DFLAGS} ${OFLAGS} --pdf" "${BASE}.pdf"
php: ${BASE}.php
sweave: ${BASE}.Rnw
tex: ${BASE}.tex
text: ${BASE}.text
man: ${BASE}.1

pdfclean: pdf cleantex
dviclean: dvi cleantex

makefile:
	${DEPLATE} -m makefile ${DFLAGS} ${OFLAGS} ${BASE}#{suffix} ${OTHER}

website:
	make FILE="${FILE}" prepare_website
	${DEPLATE} ${DFLAGS} ${OFLAGS} ${WEBSITE_DFLAGS} ${FILE} ${OTHER}
	echo ${WEBSITE_DIR}/${BASE}.html > .last_output

%.html: %#{suffix}
	make FILE="${FILE}" prepare_html
	${DEPLATE} ${DFLAGS} ${OFLAGS} ${HTML_DFLAGS} $< ${OTHER}
	echo ${HTML_DIR}/$@ > .last_output

%.xhtml: %#{suffix}
	make FILE="${FILE}" prepare_xhtml
	${DEPLATE} ${DFLAGS} ${OFLAGS} ${XHTML_DFLAGS} $< ${OTHER}
	echo ${XHTML_DIR}/$@ > .last_output

%.Rnw: %#{suffix}
	make FILE="${FILE}" prepare_sweave
	${DEPLATE} ${DFLAGS} ${OFLAGS} ${SWEAVE_DFLAGS} $< ${OTHER}
	echo ${TEX_DIR}/$@ > .last_output

%.text: %#{suffix}
	make FILE="${FILE}" prepare_text
	${DEPLATE} ${DFLAGS} ${OFLAGS} ${TEXT_DFLAGS} $< ${OTHER}
	echo ${TEXT_DIR}/$@ > .last_output

%.php: %#{suffix}
	make FILE="${FILE}" prepare_php
	${DEPLATE} ${DFLAGS} ${OFLAGS} ${PHP_DFLAGS} $< ${OTHER}
	echo ${PHP_DIR}/$@ > .last_output

%.dbk: %#{suffix}
	make FILE="${FILE}" prepare_dbk
	${DEPLATE} ${DFLAGS} ${OFLAGS} ${DBK_DFLAGS} $< ${OTHER}
	echo ${DBK_DIR}/$@ > .last_output

%.tex: %#{suffix}
	make FILE="${FILE}" prepare_tex
	${DEPLATE} ${DFLAGS} ${OFLAGS} ${TEX_DFLAGS} $< ${OTHER}
	echo ${TEX_DIR}/$@ > .last_output

%.ref: %#{suffix}
	make FILE="${FILE}" prepare_ref
	${DEPLATE} ${DFLAGS} ${OFLAGS} ${REF_DFLAGS} -o $@ $< ${OTHER}
	echo ${REF_DIR}/$@ > .last_output

%.dvi: %.tex
	make FILE="${FILE}" prepare_dvi
	cd ${TEX_DIR}; \\
	latex ${LATEX_FLAGS} $<; \\
	bibtex ${BIBTEX_FLAGS} $*; \\
	latex ${LATEX_FLAGS} $<; \\
	latex ${LATEX_FLAGS} $<;
	echo ${TEX_DIR}/$@ > .last_output

# %.pdf: %.Rnw
sweavepdf:
	make FILE="${FILE}" DFLAGS="${DFLAGS} --pdf" sweave
	cd ${TEX_DIR}; \\
	R CMD Sweave ${BASE}.Rnw; \\
	$(call postprocess_sweave, ${BASE}.tex)
	make FILE="${FILE}" prepare_pdf
	cd ${TEX_DIR}; \\
	pdflatex ${PDFLATEX_FLAGS} ${BASE}.tex; \\
	bibtex ${BIBTEX_FLAGS} ${BASE}; \\
	pdflatex ${PDFLATEX_FLAGS} ${BASE}.tex; \\
	pdflatex ${PDFLATEX_FLAGS} ${BASE}.tex
	echo ${TEX_DIR}/${BASE}.pdf > .last_output

%.pdf: %.tex
	make FILE="${FILE}" prepare_pdf
	cd ${TEX_DIR}; \\
	pdflatex ${PDFLATEX_FLAGS} $<; \\
	bibtex ${BIBTEX_FLAGS} $*; \\
	pdflatex ${PDFLATEX_FLAGS} $<; \\
	pdflatex ${PDFLATEX_FLAGS} $<
	echo ${TEX_DIR}/$@ > .last_output

%.1: %.ref
	cd ${REF_DIR}; \\
	xmlto man $<
	echo ${REF_DIR}/$@ > .last_output

view: show
show:
	#{genericViewer} `cat .last_output`

cleantex:
	cd ${TEX_DIR}; \\
	rm -f *.toc *.aux *.log *.cp *.fn *.tp *.vr *.pg *.ky \\
	*.blg *.bbl *.out *.lot *.ind *.4tc *.4ct \\
	*.ilg *.idx *.idv *.lg *.xref || echo Nothing to be done!

MAKEFILE

        log('Writing Makefile', :anyway)
        File.open(Deplate::Core.file_join(@options.dir, 'Makefile'), 'w') do |io|
            io.puts makefile
        end
        if File.exist?('Makefile.config')
            log('Makefile.config already exists', :anyway)
        else
            log('Writing Makefile.config', :anyway)
            fname = find_in_lib('Makefile.config', :pwd => true)
            if fname
                log(['Makefile.config', fname])
                cfg  = File.open(fname) {|io| io.read}
                tmpl = Deplate::Template.new(:template  => cfg)
                args = {
                    'base0'   => clean_makefile_name(base0, 2),
                    'base'    => clean_makefile_name(base, 2),
                    'files'   => files ? clean_makefile_name(files.join(' '), 2) : nil,
                    'options' => clean_makefile_name(options.join(' '), 2),
                }
                config = nil
                Deplate::Define.let_variables(self, args) do
                    config = tmpl.fill_in(self)
                end
                File.open(Deplate::Core.file_join(@options.dir, 'Makefile.config'), 'w') do |io|
                    io.puts config
                end
            else
                log(['File not found', 'Makefile.config'], :error)
            end
        end
        exit 0
    end


    def clean_makefile_name(text, multiplier=1)
        backslash = '\\\\' * multiplier
        text.gsub(/[$]/, "#{backslash}\\0")
    end

end

