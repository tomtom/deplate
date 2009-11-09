#Mingle type=pre slot=css:
<!--[if IE]>
<link rel="stylesheet" type="text/css" href="tabbar-right-ie.css" media="screen">
<![endif]-->
#End
#PREMATTER

<div id="tabFrame">
    <div id="tabBodyFrame">
        <div id="tabBody">
            <img width="600px" height="1px" src="spacer.png" alt="" />
            #BODY: -navbar_top -navbar_bottom
        </div>
        #ARG: pageComment()
        #POSTMATTER: html_pageicons_beg..html_pageicons_end
    </div>
    <div id="tabBar">
        #ARG: tabBarRight(spacer=spacer.png depth=2 depthInactive=1)
    </div>
</div>

#POSTMATTER
