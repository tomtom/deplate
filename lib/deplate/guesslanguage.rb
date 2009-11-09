# encoding: ASCII
# guesslanguage.rb
# @Author:      Tom Link (micathom AT gmail com)
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     2006-12-29.
# @Last Change: 2009-11-09.
# @Revision:    0.1.25

require 'zlib'

# This is ported form/based on:
# - Title: Guess language of text using ZIP
# - Submitter: Dirk Holtwick
# - Last Updated: 2004/12/07
# - Version no: 1.2
# - Category: Algorithms 
# http://aspn.activestate.com/ASPN/Cookbook/Python/Recipe/355807
# http://www.heise.de/newsticker/data/wst-28.01.02-003/
# http://xxx.uni-augsburg.de/format/cond-mat/0108530
class Guesslanguage
    def initialize
        @data = []
    end

    def zip(text)
        Zlib::Deflate.new.deflate(text, Zlib::FINISH)
    end

    # register a text as corpus for a language or author.
    # <name> may also be a function or whatever you need
    # to handle the result.
    def register(name, corpus)
        ziplen = zip(corpus).size
        @data << [name, corpus, ziplen]
    end

    # <part> is a text that will be compared with the registered
    # corpora and the function will return what you defined as
    # <name> in the registration process.
    def guess_with_diff(part)
        what = nil
        diff = nil
        for name, corpus, ziplen in @data
            nz = zip(corpus + part).size - ziplen
            if diff.nil? or nz < diff
                what = name
                diff = nz
            end
        end
        return [diff.to_f/part.size, what]
    end

    def guess(part)
        diff, lang = guess_with_diff(part)
        lang
    end
end

