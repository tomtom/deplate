# encoding: ASCII
# smiley.rb
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     16-Nov-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.71
# 
# Description:
# 
# Usage:
# 
# TODO:
# 
# CHANGES:
# 

class Deplate::Particle::Smiley < Deplate::Particle
    register_particle
    set_rx(nil)
    @smileys = {}
    
    class << self
        attr_reader :smileys
        def def_smiley(text, img, deplate=nil)
            @smileys[text] = img
            set_rx Regexp.new(%{^(%s)} % @smileys.keys.collect{|t| Regexp.escape(t)}.join('|'))
            if deplate
                deplate.register_particle(self.class)
            end
        end
    end

    def_smiley(':-)', 'smiley')
    # def_smiley(':-(', 'smiley_sad')
    # def_smiley(';-)', 'smiley_blink')
    #
    # http://en.wikipedia.org/wiki/Emoticon
    # :-) 	smile
    # :-( 	frown: sadness or sympathy
    # :-/ or :-\ 	somewhat unhappy/discontent, undecided, or mild 
    # anger
    # :-| 	unsure, deadpan or indifferent
    # ;-) 	wink
    # :-D 	wide grin
    # :-P or :-p 	tongue sticking out: joke, sarcasm or disgusting
    # B-) or 8-) 	has sunglasses: looking cool
    # :-o or :-O or =-o or :-0 	surprised
    # :-s or :-S 	confused
    # :-8 or :-B 	buck teeth
    # :-x 	"I shouldn't have said that"
    # :'-( or :~-( 	shedding a tear
    # :o) 	larger nose, can mean 'tongue-in-cheek', more often just 
    # 'clowning around'
    # >:-) or }:-) 	lowered eyebrows, evil or mean, a devil
    # 0:-) 	halo over the head, an angel, innocent
    #
    # Anime Style:
    # (^_^) 	smiley
    # (^.^) 	see above, but rather than a wide, closed mouth, a small 
    # mouth is present (the dot can also be a nose)
    # (~_~) 	annoyed or sleepy
    # (`_^) or (^_~) 	wink
    # (>_<) 	angry, frustrated
    # (^o^) 	singing, or laughing maniacally
    # \(^o^)/ 	very excited (raising hands)
    # (-_-) or (=_=) 	trying to hide annoyance, or sleeping (eyes 
    # shut), grumpy
    # (-_-;) or (^_^') or (^_^);; 	nervousness, or sweatdrop 
    # (embarrassed. semicolon can be repeated)
    # (-_-¤) 	vein (used to show frustration)
    # (¬_¬) 	focused at a particular person, or sometimes used after 
    # a joking comment as a sort of "shifty eyes" smiley
    # \m/>_<\m/ 	Rockin' out.
    # (<_<) 	"yeah, right...", looking around suspiciously
    # (;_;) 	crying
    # (T_T) 	crying a LOT, or deadpan stare
    # (T0T) 	crying a lot, and wailing
    # (@_@) 	dazed
    # (@_o) 	black eye from left hook
    # (o_O) or (ô_O) 	Confused Surprise
    # (o.0); 	You Scare Me
    # (ô_ô) 	Surprised
    # (0_<) 	Flinch, nervous wink
    # (O_O) 	Shocked
    # (._.) 	intimidated, sad, ashamed
    # ($_$) 	Money Eyes; Thinking about Money
    # (x_x) or (+_+) 	Dead or Knocked Out
    # (n_n) 	Pleased
    # (9_9) 	Eye Rolling
    # (*_*) 	Star-Struck
    # t(-_-t) 	Flipping off
    # (",) 	Smirk
    # ("o) 	Side Shocked
    # ~~(=_=)~~ 	Break-dance

    def setup
        @elt = @match[1]
    end

    def process
        # sfx = @deplate.variables["smileySfx"] || @deplate.variables["imgSfx"] || "png"
        img = self.class.smileys[@elt]
        if img
            # @elt = @deplate.formatter.include_image(self, "#{img}.#{sfx}", {"alt" => @elt}, true)
            @elt = @deplate.formatter.include_image(self, img, {"alt" => @elt}, true)
        else
            log(["Unknown smiley", @elt], :error)
        end
    end
end

