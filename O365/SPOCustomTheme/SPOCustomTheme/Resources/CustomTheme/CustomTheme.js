var jQuery = "https://ajax.aspnetcdn.com/ajax/jQuery/jquery-2.0.2.min.js";

// Is MDS enabled?
if ("undefined" != typeof g_MinimalDownload && g_MinimalDownload && (window.location.pathname.toLowerCase()).endsWith("/_layouts/15/start.aspx") && "undefined" != typeof asyncDeltaManager) {
    // Register script for MDS if possible
    RegisterModuleInit("CustomTheme.js", JavaScript_Embed); //MDS registration
    JavaScript_Embed(); //non MDS run
} else {
    JavaScript_Embed();
}

//function JavaScript_Embed() {

//    loadScript(jQuery, function () {
//        $(document).ready(function () {
//            var message = "<img src='/_Layouts/Images/STS_ListItem_43216.gif' align='absmiddle'> <font color='#AA0000'>JavaScript customization is <i>fun</i>!</font>"

//            // Execute status setter only after SP.JS has been loaded
//            SP.SOD.executeOrDelayUntilScriptLoaded(function () { SetStatusBar(message); }, 'sp.js');

//            // Customize the viewlsts.aspx page
//            if (IsOnPage("viewlsts.aspx")) {
//                //hide the subsites link on the viewlsts.aspx page
//                $("#createnewsite").parent().hide();
//            }
//        });
//    });
//}

//function SetStatusBar(message) {
//    var strStatusID = SP.UI.Status.addStatus("Information : ", message, true);
//    SP.UI.Status.setStatusPriColor(strStatusID, "yellow");
//}

//function IsOnPage(pageName) {
//    if (window.location.href.toLowerCase().indexOf(pageName.toLowerCase()) > -1) {
//        return true;
//    } else {
//        return false;
//    }
//}

function JavaScript_Embed() {

    loadScript(jQuery, function () {
        $(document).ready(function () {
            ExecuteOrDelayUntilScriptLoaded(checkifUserHasFullPermissions, "sp.js");
            var siteURL = $(location).attr('href');
            if (siteURL.indexOf('https://testmiamiedu.sharepoint.com/sites/syntheme/_layouts/15/addanapp.aspx') != -1 || siteURL.indexOf('Lists/test/calendar.aspx') != -1 || siteURL.indexOf('_layouts/15/groups.aspx') != -1) {

                $('.ms-belltown-sideNavDelta > *').css('display', 'none');
            }
            else {
                $('.ms-belltown-sideNavDelta > *').css('display', 'block');

            }
            if (siteURL.indexOf('/_layouts/15/viewlsts.aspx') != -1) {
                $('h2.ms-webpart-titleText, span.ms-webpart-titleText, .ms-webpart-titleText > a').css('color', '#000');
            }
            else {
                $('h2.ms-webpart-titleText, span.ms-webpart-titleText, .ms-webpart-titleText > a').css('color', '#fff');
            }
        });
    });
}

function loadScript(url, callback) {
    var head = document.getElementsByTagName("head")[0];
    var script = document.createElement("script");
    script.src = url;

    // Attach handlers for all browsers
    var done = false;
    script.onload = script.onreadystatechange = function () {
        if (!done && (!this.readyState
					|| this.readyState == "loaded"
					|| this.readyState == "complete")) {
            done = true;

            // Continue your code
            callback();

            // Handle memory leak in IE
            script.onload = script.onreadystatechange = null;
            head.removeChild(script);
        }
    };

    head.appendChild(script);
}

function checkifUserHasFullPermissions() {
    context = new SP.ClientContext.get_current();
    web = context.get_web();
    this._currentUser = web.get_currentUser();
    context.load(this._currentUser);
    context.load(web, 'EffectiveBasePermissions');
    context.executeQueryAsync(Function.createDelegate(this, this.onSuccessMethod), Function.createDelegate(this, this.onFailureMethod));
    $('#s4-workspace').css('visibility', 'visible');
}

function onSuccessMethod(sender, args) {
    if (web.get_effectiveBasePermissions().has(SP.PermissionKind.fullMask)) {
        checkRootList(true);
    }
    else if (web.get_effectiveBasePermissions().has(SP.PermissionKind.manageWeb)) {
        checkRootList(true);
    }
    else {
        var rootCount = 0;
        $("span[id$=ctl00_siteMapPath] span a").each(function () {
            rootCount = rootCount + 1;
        });
        if (rootCount != 1) {
            var siteURL = $(location).attr('href');
            var fullControlUrlNodeIndex = siteURL.lastIndexOf('.app') + 4;
            var fullControlUrlPath = siteURL.substring(0, siteURL.lastIndexOf('.app') + 4);
            var fullControlURLExtention = fullControlUrlPath.substring((fullControlUrlNodeIndex - 4), fullControlUrlNodeIndex);
            if (fullControlURLExtention === '.app') {
                var isSitePage = siteURL.lastIndexOf('SitePages');
                if (isSitePage === -1) {
                    isSitePage = siteURL.lastIndexOf('NewForm.aspx');
                    if (isSitePage === -1) {
                        var siteCollectionPath = _spPageContextInfo.siteServerRelativeUrl;
                        window.location = "http://" + window.location.host + "/" + siteCollectionPath + "/SitePages/AccessDenied.aspx?homeSite=" + _spPageContextInfo.webServerRelativeUrl;
                    }
                    else {
                        checkRootList(true);
                    }
                }
                else {
                    isSitePage = siteURL.lastIndexOf('AllPages.aspx');
                    if (isSitePage != -1) {
                        var siteCollectionPath = _spPageContextInfo.siteServerRelativeUrl;
                        window.location = "http://" + window.location.host + "/" + siteCollectionPath + "/SitePages/AccessDenied.aspx?homeSite=" + _spPageContextInfo.webServerRelativeUrl;
                    }
                    else {
                        checkRootList(true);
                    }
                }
                HideRibbon();
            }
            else {
                checkRootList(true);
            }
        }
        else {
            $("#searchInputBox").css("display", "");
            checkRootList(true);
        }
    }
}

function onFailureMethod(sender, args) {
    var rootCount = 0;
    $("span[id$=ctl00_siteMapPath] span a").each(function () {
        rootCount = rootCount + 1;
    });

    if (rootCount != 1) {
        var siteURL = $(location).attr('href');
        var fullControlUrlNodeIndex = siteURL.lastIndexOf('.app') + 4;
        var fullControlUrlPath = siteURL.substring(0, siteURL.lastIndexOf('.app') + 4);
        var fullControlURLExtention = fullControlUrlPath.substring((fullControlUrlNodeIndex - 4), fullControlUrlNodeIndex);
        if (fullControlURLExtention === '.app') {
            var isSitePage = siteURL.lastIndexOf('SitePages');
            if (isSitePage === -1) {
                isSitePage = siteURL.lastIndexOf('NewForm.aspx');
                if (isSitePage === -1) {
                    var siteCollectionPath = _spPageContextInfo.siteServerRelativeUrl;
                    window.location = "http://" + window.location.host + "/" + siteCollectionPath + "/SitePages/AccessDenied.aspx?homeSite=" + _spPageContextInfo.webServerRelativeUrl;
                }
                else {
                    checkRootList(false);
                }
            }
            else {
                isSitePage = siteURL.lastIndexOf('AllPages.aspx');
                if (isSitePage != -1) {
                    var siteCollectionPath = _spPageContextInfo.siteServerRelativeUrl;
                    window.location = "http://" + window.location.host + "/" + siteCollectionPath + "/SitePages/AccessDenied.aspx?homeSite=" + _spPageContextInfo.webServerRelativeUrl;
                }
                else {
                    checkRootList(false);
                }
            }
            HideRibbon();
        }
        else {
            checkRootList(false);
        }
    }
    else {
        $("#searchInputBox").css("display", "");
        checkRootList(false);
    }
}

function HideRibbon() {
    $('#ms-designer-ribbon').hide();
    var newHeight = $(document).height();
    if ($.browser.msie) { newHeight = newHeight - 3; }
    $("#s4-workspace").height(newHeight);
}

function checkRootList(fullControlFlag) {
    var siteURL = $(location).attr('href');
    var siteWebURL = _spPageContextInfo.webServerRelativeUrl;
    var siteWebURLIndex = siteWebURL.lastIndexOf('/');
    var siteWebURLName = siteWebURL.substring(siteWebURLIndex + 1);
    var ignoreUrlPathIndex = siteWebURL.lastIndexOf('/') + 1;
    var rootSite = siteWebURL.substring(ignoreUrlPathIndex);
    var fullControlUrlNodeIndex = siteURL.lastIndexOf('.app') + 4;
    var fullControlUrlPath = siteURL.substring(0, siteURL.lastIndexOf('.app') + 4);
    var ignorefullControlUrlPathIndex = fullControlUrlPath.lastIndexOf('/') + 1;
    var fullControlURLNode = fullControlUrlPath.substring(ignorefullControlUrlPathIndex, fullControlUrlNodeIndex);

    if (siteWebURLName != fullControlURLNode)
        fullControlURLNode = siteURL.substring(ignorefullControlUrlPathIndex, (fullControlUrlNodeIndex + 2));

    var fullControlURLExtention = fullControlUrlPath.substring((fullControlUrlNodeIndex - 4), fullControlUrlNodeIndex);

    if (fullControlFlag == false && fullControlURLExtention === '.app') { }
    else
    {
        fullControlFlag = true;
    }
    readFile(rootSite, fullControlURLNode, fullControlFlag);

}

function subsiteAsRootsite(rootSite, fullControlURLNode, fullControlFlag) {
    var siteURL = $(location).attr('href');

    if (rootSite != '-') {
        var flag = false;
        var rootCount = 0;
        var rootURL;

        $("span[id$=ctl00_siteMapPath] span a").each(function () {
            if ($(this).attr('href').indexOf(rootSite) === -1) {
                rootCount = rootCount + 1;
            }
            else {
                $("#ctl00_onetidProjectPropertyTitleGraphic").attr("href", $(this).attr('href'));
            }
        });

        var loopCount = 0;
        $("span[id$=ctl00_siteMapPath] span a").each(function () {
            if (loopCount < rootCount) {
                $(this).hide();
                $(this).parent().next("span").css('display', 'none');
            }
            loopCount = loopCount + 1;
        });
    }

    var totalSite = 0;
    $("span[id$=ctl00_siteMapPath] span a").each(function () {
        if ($(this).attr('href').indexOf(fullControlURLNode) != -1) {
            $("#ctl00_onetidProjectPropertyTitleGraphic").attr("href", $(this).attr('href'));
        }

        if (fullControlURLNode != '-' && fullControlFlag == false) {
            $(this).hide();
            $(this).parent().next("span").css('display', 'none');
            $('#rtArrow').css("display", "none");
        }
        else {
            var entryTitle = $(this).text().trim();
            if (entryTitle.length > 50) {
                var chopCharacter = entryTitle.substring(0, 50);
                $(this).text(chopCharacter);
            }
        }

        totalSite = totalSite + 1;
    });

    if (totalSite > 3 /*&& fullControlURLNode == '-' && fullControlFlag == true*/) {
        var countSite = totalSite - 3;
        var count = 0;
        $("span[id$=ctl00_siteMapPath] span a").each(function () {
            if (count != 0) {
                if (count < countSite) {
                    $(this).hide();
                    $(this).parent().next("span").css('display', 'none');
                }
                if (count === countSite) {
                    $(this).parent().text("..");
                }
            }
            count = count + 1;
        });

    }

    var contentMapFlag = false;
    var totalFolders = 0;
    $("span[id$=ctl00_PlaceHolderPageTitleInTitleArea_ContentMap] span a").each(function () {
        if (totalFolders == 0) {
            $(this).hide();
            $(this).parent().next("span").css('display', 'none');
        }

        if (fullControlURLNode != '-' && fullControlFlag == false) {
            $(this).hide();
            $(this).parent().next("span").css('display', 'none');
            $('#rtArrow').css("display", "none");
        }
        else {
            var entryTitle = $(this).text().trim();
            if (entryTitle.length > 50) {
                var chopCharacter = entryTitle.substring(0, 50);
                $(this).text(chopCharacter);
            }
        }
        totalFolders = totalFolders + 1;
        contentMapFlag = true;
    });

    if (totalFolders > 3) {
        var countSite = totalFolders - 2;
        var count = 0;
        $("span[id$=ctl00_PlaceHolderPageTitleInTitleArea_ContentMap] span a").each(function () {
            if (count > 1) {
                if (count < countSite) {
                    $(this).hide();
                    $(this).parent().next("span").css('display', 'none');
                }
                if (count === countSite) {
                    $(this).parent().text("..");
                }
            }
            count = count + 1;
        });

    }

    var entryTitle = $('span#ctl00_PlaceHolderPageTitleInTitleArea_ContentMap span.ms-sitemapdirectional:last-child').text().trim();
    if (entryTitle.length > 50) {
        var chopCharacter = entryTitle.substring(0, 50);
        $('span#ctl00_PlaceHolderPageTitleInTitleArea_ContentMap span.ms-sitemapdirectional:last-child').text(chopCharacter);
    }

    if (fullControlURLNode != '-' && contentMapFlag == false && fullControlFlag == false) {
        var entryTitle = $('span#DeltaPlaceHolderPageTitleInTitleArea').text().trim();
        if (entryTitle.length > 0) {
            $('span#DeltaPlaceHolderPageTitleInTitleArea').text(entryTitle);
        }
    }

    if (fullControlFlag == true) {
        $("#searchInputBox").css("display", "");
    }
}
function readFile(rootSite, fullControlURLNode, fullControlFlag) {
    var clientContext;
    var oWebsite;
    var fileUrl;

    clientContext = new SP.ClientContext.get_current();
    oWebsite = clientContext.get_web();

    clientContext.load(oWebsite);
    clientContext.executeQueryAsync(function () {
        fileUrl = oWebsite.get_serverRelativeUrl() +
            "/SiteAssets/Root.txt";
        $.ajax({
            url: fileUrl,
            type: "GET"
        })
            .done(Function.createDelegate(this, successHandler))
            .error(Function.createDelegate(this, errorHandler));
    }, errorHandler);

    function successHandler(data) {

        var siteURL = $(location).attr('href');


        var flag = false;
        var rootCount = 0;
        var rootURL;

        $("span[id$=ctl00_siteMapPath] span a").each(function () {
            if ($(this).attr('href').indexOf(rootSite) === -1) {
                rootCount = rootCount + 1;
            }
            else {
                $("#ctl00_onetidProjectPropertyTitleGraphic").attr("href", $(this).attr('href'));
            }
        });

        var loopCount = 0;
        $("span[id$=ctl00_siteMapPath] span a").each(function () {
            if (loopCount < rootCount) {
                $(this).hide();
                $(this).parent().next("span").css('display', 'none');
            }
            loopCount = loopCount + 1;
        });

        var totalSite = 0;
        $("span[id$=ctl00_siteMapPath] span a").each(function () {
            if ($(this).attr('href').indexOf(fullControlURLNode) != -1) {
                $("#ctl00_onetidProjectPropertyTitleGraphic").attr("href", $(this).attr('href'));
            }

            if (fullControlURLNode != '-' && fullControlFlag == false) {
                $(this).hide();
                $(this).parent().next("span").css('display', 'none');
                $('#rtArrow').css("display", "none");
            }
            else {
                var entryTitle = $(this).text().trim();
                if (entryTitle.length > 50) {
                    var chopCharacter = entryTitle.substring(0, 50);
                    $(this).text(chopCharacter);
                }
            }

            totalSite = totalSite + 1;
        });

        if (totalSite > 3 /*&& fullControlURLNode == '-' && fullControlFlag == true*/) {
            var countSite = totalSite - 3;
            var count = 0;
            $("span[id$=ctl00_siteMapPath] span a").each(function () {
                if (count != 0) {
                    if (count < countSite) {
                        $(this).hide();
                        $(this).parent().next("span").css('display', 'none');
                    }
                    if (count === countSite) {
                        $(this).parent().text("..");
                    }
                }
                count = count + 1;
            });

        }

        var contentMapFlag = false;
        var totalFolders = 0;
        $("span[id$=ctl00_PlaceHolderPageTitleInTitleArea_ContentMap] span a").each(function () {
            if (totalFolders == 0) {
                $(this).hide();
                $(this).parent().next("span").css('display', 'none');
            }

            if (fullControlURLNode != '-' && fullControlFlag == false) {
                $(this).hide();
                $(this).parent().next("span").css('display', 'none');
                $('#rtArrow').css("display", "none");
            }
            else {
                var entryTitle = $(this).text().trim();
                if (entryTitle.length > 50) {
                    var chopCharacter = entryTitle.substring(0, 50);
                    $(this).text(chopCharacter);
                }
            }
            totalFolders = totalFolders + 1;
            contentMapFlag = true;
        });

        if (totalFolders > 3) {
            var countSite = totalFolders - 2;
            var count = 0;
            $("span[id$=ctl00_PlaceHolderPageTitleInTitleArea_ContentMap] span a").each(function () {
                if (count > 1) {
                    if (count < countSite) {
                        $(this).hide();
                        $(this).parent().next("span").css('display', 'none');
                    }
                    if (count === countSite) {
                        $(this).parent().text("..");
                    }
                }
                count = count + 1;
            });

        }

        var entryTitle = $('span#ctl00_PlaceHolderPageTitleInTitleArea_ContentMap span.ms-sitemapdirectional:last-child').text().trim();
        if (entryTitle.length > 50) {
            var chopCharacter = entryTitle.substring(0, 50);
            $('span#ctl00_PlaceHolderPageTitleInTitleArea_ContentMap span.ms-sitemapdirectional:last-child').text(chopCharacter);
        }

        if (fullControlURLNode != '-' && contentMapFlag == false && fullControlFlag == false) {
            var entryTitle = $('span#DeltaPlaceHolderPageTitleInTitleArea').text().trim();
            if (entryTitle.length > 0) {
                $('span#DeltaPlaceHolderPageTitleInTitleArea').text(entryTitle);
            }
        }

        if (fullControlFlag == true) {
            $("#searchInputBox").css("display", "");
        }
        var checkduplicate = $(".breadcrumbCurrent").html();
        $(".ms-sitemapdirectional").each(function (an) {
            if ($(this).html() == checkduplicate && $(location).attr('href').indexOf('_layouts/15/osssearchresults.aspx') == -1) {
                $(this).css('display', 'none');
                $(this).parent().next("span").css('display', 'none');

            }
        });
        $("#navigation").show();

    }

    function errorHandler() {

        subsiteAsRootsite("-", fullControlURLNode, fullControlFlag);
        var checkduplicate = $(".breadcrumbCurrent").html();
        $(".ms-sitemapdirectional").each(function (an) {
            if ($(this).html() == checkduplicate && $(location).attr('href').indexOf('_layouts/15/osssearchresults.aspx') == -1) {
                $(this).css('display', 'none');
                $(this).parent().next("span").css('display', 'none');
            }
        });
        if ($('#DeltaPlaceHolderPageTitleInTitleArea').html().trim() == checkduplicate) {
            $('#DeltaPlaceHolderPageTitleInTitleArea').html("Home");

        }
        $("#navigation").show();

    }
    //$("#navigation").show();
}