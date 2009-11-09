// #BEGIN dhtml.js: Extract from DHTML-Bibliothek
// (SelfHTML -> DHTML -> Allgemeine DHTML-Bibliothek)
// http://selfhtml.teamone.de/
var DHTML = 0, DOM = 0, MS = 0, NS = 0, OP = 0;

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

// #END dhtml.js

PinDown     = new Image();
PinDown.src = "pin-down.png";
PinUp       = new Image();
PinUp.src   = "pin-up.png";

var TabBarFloating  = true;
var StandardTimeout = 8000;
var MovingTimeout   = 1;
var Headroom        = 10;

function GetSetting() {
    if(document.cookie) {
        var Values = document.cookie.split(";");
        for (var Setting in Values) {
            var KeyVal = Values[Setting].split("=");
            var Key = KeyVal[0];
            var Val = KeyVal[1];
            if (Key == "tbfloat")
                TabBarFloating = (Val == "1");
        }
    }
}
GetSetting();

function SaveSettings() {
    var now = new Date();
    var expire = new Date(now.getTime() + (1000*60*60*24 * 90));
    if (TabBarFloating)
        var pin = "1";
    else
        var pin = "0";
    // document.cookie = "tbfloat=" + pin + ";expires=" + expire.toGMTString();
    document.cookie = "tbfloat=" + pin;
}

function SetStickyTabbar() {
    var TabBarStyle = document.getElementById("tabBar").style;
    if (TabBarFloating) {
        // window.document.images[0].src = PinUp.src;
        document.getElementById("pinImg").src = PinUp.src;
        TabBarStyle.position = "absolute";
        TabBarStyle.top = GetTop() + Headroom;
        TabBarStyle.left = 10;
        RepositionTabBar();
    } else {
        // window.document.images[0].src = PinDown.src;
        document.getElementById("pinImg").src = PinDown.src;
        TabBarStyle.position = "fixed";
        TabBarStyle.top = Headroom;
        TabBarStyle.left = 10;
    }
}

function GetTop() {
    if(MS) {
        return document.body.scrollTop;
    } else {
        return window.pageYOffset;
    }
}

function GetWinHeight() {
    if(MS) {
        return document.body.offsetHeight;
    } else {
        return window.innerHeight;
    }
}

function ToggleSticky() {
    TabBarFloating = !TabBarFloating;
    SetStickyTabbar();
    SaveSettings();
}

function opacity(Delta) {
    if (Delta <= 7)
        return 1;
    else
        return 7.0 / Math.abs(Delta);
}

function RepositionTabBar() {
    if(TabBarFloating && DOM) {
        var TabBarStyle = document.getElementById("tabBar").style;
        var Pos = parseInt(TabBarStyle.top);
        var Top = GetTop();
        var WinHeight = GetWinHeight();
        var Diff = Pos - Top;
        var Delta = Math.sqrt(Math.abs(Diff));
        if (Delta > 40)
            Delta = Math.abs(Diff) - Headroom;

        if (Diff > WinHeight) {
            TabBarStyle.top = Top + WinHeight;
            // TabBarStyle.opacity = 0;
            window.setTimeout('RepositionTabBar()', MovingTimeout);
            return;
        } else if (Diff > 30) {
            TabBarStyle.top = Pos - Delta;
            // TabBarStyle.opacity = opacity(Delta);
            window.setTimeout('RepositionTabBar()', MovingTimeout);
            return;
        } else if (Diff < -500) {
            TabBarStyle.top = Top - 500;
            // TabBarStyle.opacity = 0;
            window.setTimeout('RepositionTabBar()', MovingTimeout);
            return;
        } else if (Diff < 0) {
            TabBarStyle.top = Pos + Delta;
            // TabBarStyle.opacity = opacity(Delta);
            window.setTimeout('RepositionTabBar()', MovingTimeout);
            return;
        }
        TabBarStyle.top = Top + Headroom;
        // TabBarStyle.opacity = 1;
    }
    window.setTimeout('RepositionTabBar()', StandardTimeout);
}

window.setTimeout('RepositionTabBar()', 10);
window.setTimeout('SetStickyTabbar()', 10);

