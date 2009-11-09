class Deplate::Core
    class << self
        def builtin_modules
            return [
                "anyword",
                "babelfish",
                "code-coderay",
                "code-gvim",
                "code-gvim71",
                "code-highlight",
                "colored-log",
                "encode",
                "endnotes",
                "entities-decode",
                "entities-encode",
                "guesslanguage",
                "html-asciimath",
                "html-deplate-button",
                "html-headings-navbar",
                "html-highstep",
                "html-jsmath",
                "html-mathml",
                "html-obfuscate-email",
                "html-sidebar",
                "htmlslides-navbar-fh",
                "iconv",
                "imgurl",
                "inlatex-compound",
                "koma",
                "lang-de",
                "lang-en",
                "lang-ru-koi8-r",
                "lang-ru",
                "lang-zh_CN-autospace",
                "lang-zh_CN",
                "latex-emph-table-head",
                "latex-styles",
                "latex-verbatim-small",
                "linkmap",
                "makefile",
                "mark-external-urls",
                "markup-1-warn",
                "markup-1",
                "navbar-png",
                "noindent",
                "numpara",
                "particle-math",
                "php-extra",
                "pstoedit",
                "recode",
                "smart-dash",
                "smiley",
                "soffice",
                "symbols-latin1",
                "symbols-od-utf-8",
                "symbols-plain",
                "symbols-sgml",
                "symbols-utf-8",
                "symbols-xml",
                "syntax-region-alt",
                "utf8",
                "validate-html",
            ]
        end

        def builtin_formatters
            return [
                "dbk-article-4.1.2",
                "dbk-article",
                "dbk-book",
                "dbk-ref",
                "dbk-slides",
                "dbk-snippet",
                "html-snippet",
                "html",
                "htmlsite",
                "htmlslides",
                "htmlwebsite",
                "latex-dramatist",
                "latex-snippet",
                "latex",
                "null",
                "php",
                "phpsite",
                "plain",
                "sweave",
                "template",
                "xhtml10t",
                "xhtml11m",
            ]
        end

        def builtin_css
            return []
        end
    
        def builtin_input
            return [
                "deplate-headings",
                "deplate-restricted",
                "deplate",
                "play",
                "rdoc",
                "template",
            ]
        end
    
        def builtin_metadata
            return [
            ]
        end
    
        def builtin_locale
            return [
            ]
        end
    end
end
