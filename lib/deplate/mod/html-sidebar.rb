# encoding: ASCII
# mod-html-sidebar.rb -- A popup-mini-toc for html output
# @Author:      Tom Link (micathom AT gmail com)
# @Website:     http://deplate.sf.net/
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     19-Jul-2004.
# @Last Change: 2009-11-09.
# @Revision:    0.53
# 
# Description:
# 
# Usage:
# 
# TODO:
# 
# CHANGES:
# 

class Deplate::Formatter::HTML
    def prepare_html_sidebar
        opt0  = @deplate.variables["bodyOptions"]
        @deplate.variables["navGif"] ||= "navigation_back.gif"
        optSB = %{onload="Event_init()" background="#{@deplate.variables["navGif"]}"}
        @deplate.variables["bodyOptions"] = opt0 ? "%s %s" % [opt0, optSB] : optSB
        
        mouseThresholdIn  = @deplate.variables["mouseThresholdIn"]  || 420
        mouseThresholdOut = @deplate.variables["mouseThresholdOut"] || 270
        
        html = <<EndOfHTML
<!-- Based on code from selfhtml: http://selfhtml.teamone.de/ -->
<!-- dhtml.js: DHTML-Bibliothek (SelfHTML -> DHTML -> Allgemeine DHTML-Bibliothek) -->
<script type="text/javascript">
<!--
var DHTML = 0, DOM = 0, MS = 0, NS = 0, OP = 0;

function DHTML_init() {

 if (window.opera) {
     OP = 1;
 }
 if(document.getElementById) {
   DHTML = 1;
   DOM = 1;
 }
 if(document.all && !OP) {
   DHTML = 1;
   MS = 1;
 }
if(document.layers && !OP) {
   DHTML = 1;
   NS = 1;
 }
}

function getElem(p1,p2,p3) {
 var Elem;
 if(DOM) {
   if(p1.toLowerCase()=="id") {
     if (typeof document.getElementById(p2) == "object")
     Elem = document.getElementById(p2);
     else Elem = void(0);
     return(Elem);
   }
   else if(p1.toLowerCase()=="name") {
     if (typeof document.getElementsByName(p2) == "object")
     Elem = document.getElementsByName(p2)[p3];
     else Elem = void(0);
     return(Elem);
   }
   else if(p1.toLowerCase()=="tagname") {
     if (typeof document.getElementsByTagName(p2) == "object" ||
        (OP && typeof document.getElementsByTagName(p2) == "function"))
     Elem = document.getElementsByTagName(p2)[p3];
     else Elem = void(0);
     return(Elem);
   }
   else return void(0);
 }
 else if(MS) {
   if(p1.toLowerCase()=="id") {
     if (typeof document.all[p2] == "object")
     Elem = document.all[p2];
     else Elem = void(0);
     return(Elem);
   }
   else if(p1.toLowerCase()=="tagname") {
     if (typeof document.all.tags(p2) == "object")
     Elem = document.all.tags(p2)[p3];
     else Elem = void(0);
     return(Elem);
   }
   else if(p1.toLowerCase()=="name") {
     if (typeof document[p2] == "object")
     Elem = document[p2];
     else Elem = void(0);
     return(Elem);
   }
   else return void(0);
 }
 else if(NS) {
   if(p1.toLowerCase()=="id" || p1.toLowerCase()=="name") {
   if (typeof document[p2] == "object")
     Elem = document[p2];
     else Elem = void(0);
     return(Elem);
   }
   else if(p1.toLowerCase()=="index") {
    if (typeof document.layers[p2] == "object")
     Elem = document.layers[p2];
    else Elem = void(0);
     return(Elem);
   }
   else return void(0);
 }
}

function getCont(p1,p2,p3) {
   var Cont;
   if(DOM && getElem(p1,p2,p3) && getElem(p1,p2,p3).firstChild) {
     if(getElem(p1,p2,p3).firstChild.nodeType == 3)
       Cont = getElem(p1,p2,p3).firstChild.nodeValue;
     else
       Cont = "";
     return(Cont);
   }
   else if(MS && getElem(p1,p2,p3)) {
     Cont = getElem(p1,p2,p3).innerText;
     return(Cont);
   }
   else return void(0);
}

function getAttr(p1,p2,p3,p4) {
   var Attr;
   if((DOM || MS) && getElem(p1,p2,p3)) {
     Attr = getElem(p1,p2,p3).getAttribute(p4);
     return(Attr);
   }
   else if (NS && getElem(p1,p2)) {
       if (typeof getElem(p1,p2)[p3] == "object")
        Attr=getElem(p1,p2)[p3][p4]
       else
        Attr=getElem(p1,p2)[p4]
         return Attr;
       }
   else return void(0);
}

function setCont(p1,p2,p3,p4) {
   if(DOM && getElem(p1,p2,p3) && getElem(p1,p2,p3).firstChild)
     getElem(p1,p2,p3).firstChild.nodeValue = p4;
   else if(MS && getElem(p1,p2,p3))
     getElem(p1,p2,p3).innerText = p4;
   else if(NS && getElem(p1,p2,p3)) {
     getElem(p1,p2,p3).document.open();
     getElem(p1,p2,p3).document.write(p4);
     getElem(p1,p2,p3).document.close();
   }
}

DHTML_init();

function Menue() {
    if(DOM) {
        if(MS)
            getElem("id","Contents",null).style.top = document.body.scrollTop + 50;
        else
            getElem("id","Contents",null).style.top = window.pageYOffset + 50;
    }
    if(DOM || MS) {
        if (!DOM) getElem("id","Contents",null).style.top = document.body.scrollTop + 50;
        if (OP) getElem("id","ContentsBlock",null).style.pixelTop = NavLinksPos;
            getElem("id","Contents",null).style.visibility = "visible";
        }
    else if(NS) {
        getElem("id","Contents",null).top = window.pageYOffset + 50;
        getElem("id","Contents",null).visibility = "show";
    }
}

function noMenue() {
    if(DOM || MS)
        getElem("id","Contents",null).style.visibility = "hidden";
    if(NS)
        getElem("id","Contents",null).visibility = "hide";
}

function handleMove(ev) {
    if(!MS) {
        Event = ev;
        if(Event.screenX < #{mouseThresholdOut})
            Menue();
        else if(Event.screenX > #{mouseThresholdIn})
            noMenue();
    }
}
    
function MShandleMove() {
    if(MS) {
        if(window.event.clientX < #{mouseThresholdOut})
            Menue();
        else if(window.event.clientX > #{mouseThresholdIn})
            noMenue();
    }
}

function Event_init() {
    if(DOM && !MS && !OP) {
        getElem("tagname","body",0).addEventListener("mousemove", handleMove, true);
    }
    if(NS) {
        document.captureEvents(Event.MOUSEMOVE);
        document.onmousemove=handleMove;
    }
    if (DOM && OP) {
        document.onmousemove=handleMove;
        NavLinksPos=42; //Position des Bereiches NavLinks
        getElem("id","ContentsBlock",null).style.pixelTop=NavLinksPos;
    }
    if (MS) getElem("tagname","body",0).onmousemove=MShandleMove;
}
//-->
</script>
EndOfHTML
        output_at(:pre, :javascript, html)
        text = "minitoc"
        args = {"type"=>"pre", "slot"=>"pre_bottom"}
        minitoc = Deplate::Command::LIST.new(@deplate, nil, text, nil, args, "LIST")
        minitoc = minitoc.finish.process
        @deplate.accum_elements.unshift(minitoc)
    end
end

