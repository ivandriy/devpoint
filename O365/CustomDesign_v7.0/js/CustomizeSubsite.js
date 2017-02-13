function checkRootList(fullControlFlag)
{
	var siteURL = $(location).attr('href');

	var siteWebURL = _spPageContextInfo.webServerRelativeUrl;

	var siteWebURLIndex = siteWebURL.lastIndexOf('/');
	var siteWebURLName = siteWebURL.substring(siteWebURLIndex + 1);

	//var reqUrlPathIndex = siteURL.lastIndexOf('.r') + 2;
	//var reqUrlPath = siteURL.substring(0, siteURL.lastIndexOf('.r') + 2);
        
	var ignoreUrlPathIndex = siteWebURL.lastIndexOf('/') + 1;
	var rootSite = siteWebURL.substring(ignoreUrlPathIndex);
	
	//var reqUrlExtention = reqUrlPath.substring((reqUrlPathIndex - 2),reqUrlPathIndex);
	
	var fullControlUrlNodeIndex = siteURL.lastIndexOf('.app') + 4;
	var fullControlUrlPath = siteURL.substring(0, siteURL.lastIndexOf('.app') + 4);
	//alert(fullControlUrlPath);
	var ignorefullControlUrlPathIndex = fullControlUrlPath.lastIndexOf('/') + 1;
	var fullControlURLNode = fullControlUrlPath.substring(ignorefullControlUrlPathIndex,fullControlUrlNodeIndex);
	
	if(siteWebURLName != fullControlURLNode)
		fullControlURLNode = siteURL.substring(ignorefullControlUrlPathIndex,(fullControlUrlNodeIndex + 2));
		
	var fullControlURLExtention = fullControlUrlPath.substring((fullControlUrlNodeIndex - 4),fullControlUrlNodeIndex);

	if(fullControlFlag == false && fullControlURLExtention === '.app'){}
		else
		{
			fullControlFlag = true;
		}
	//if(reqUrlExtention === '.r')
	//{
	//	if(fullControlFlag == false && fullControlURLExtention === '.app'){}
	//	else
	//	{
	//		fullControlFlag = true;
	//	}
	//	subsiteAsRootsite(rootSite,fullControlURLNode,fullControlFlag);
	//}
	//else if(fullControlURLExtention === '.app')
	//{
	//	subsiteAsRootsite('-',fullControlURLNode,fullControlFlag);
	//}
	//else
	//{
   //		$("#searchInputBox").css("display","");
   //		subsiteAsRootsite('-','-',fullControlFlag);
	//}
	readFile(rootSite,fullControlURLNode,fullControlFlag);
	
}

function subsiteAsRootsite(rootSite,fullControlURLNode,fullControlFlag)
{	
	var siteURL = $(location).attr('href');

	if(rootSite != '-')
	{
   		var flag = false;
    	var rootCount = 0;
    	var rootURL;
    	
    	$("span[id$=ctl00_siteMapPath] span a").each(function(){
    		if($(this).attr('href').indexOf(rootSite) === -1)
    		{
    			rootCount = rootCount + 1;
    		}
    		else
    		{
    			$("#ctl00_onetidProjectPropertyTitleGraphic").attr("href", $(this).attr('href'));
    		}
    	});
    	
    	var loopCount = 0;
		$("span[id$=ctl00_siteMapPath] span a").each(function(){
			if(loopCount < rootCount)
			{
				$(this).hide();
   	   		    $(this).parent().next("span").css('display', 'none');
			}
			loopCount = loopCount + 1;
    	});
    }
    
    var totalSite = 0;
	$("span[id$=ctl00_siteMapPath] span a").each(function(){
   		if($(this).attr('href').indexOf(fullControlURLNode) != -1){
   			$("#ctl00_onetidProjectPropertyTitleGraphic").attr("href", $(this).attr('href'));	
		}
		
		if(fullControlURLNode != '-' && fullControlFlag == false)
		{
			$(this).hide();
   		    $(this).parent().next("span").css('display', 'none');
   		    $('#rtArrow').css("display","none");
		}
		else
    	{
			var entryTitle = $(this).text().trim();
  			if (entryTitle.length > 50) {
  			  var chopCharacter = entryTitle.substring(0,50);
  			  $(this).text(chopCharacter);
  			}
  		}

  		totalSite = totalSite + 1;
   	});
	
    if(totalSite > 3 /*&& fullControlURLNode == '-' && fullControlFlag == true*/)
    {
    	var countSite = totalSite - 3;
    	var count = 0;
    	$("span[id$=ctl00_siteMapPath] span a").each(function(){
    		if(count != 0)
    		{
    			if(count < countSite)
    			{
    				$(this).hide();
   		    		$(this).parent().next("span").css('display', 'none');
    			}
    			if(count === countSite)
    			{
    				$(this).parent().text("..");
    			}
    		}
    		count = count + 1;
    	});
   		
    }
    
    var contentMapFlag = false;
    var totalFolders = 0;
    $("span[id$=ctl00_PlaceHolderPageTitleInTitleArea_ContentMap] span a").each(function(){
    	if(totalFolders == 0)
    	{
    		$(this).hide();
    		$(this).parent().next("span").css('display', 'none');
    	}
    	
    	if(fullControlURLNode != '-' && fullControlFlag == false)
		{
			$(this).hide();
   		    $(this).parent().next("span").css('display', 'none');
   		    $('#rtArrow').css("display","none");
		}
		else
    	{
			var entryTitle = $(this).text().trim();
  			if (entryTitle.length > 50) {
  			  var chopCharacter = entryTitle.substring(0,50);
  			  $(this).text(chopCharacter);
  			}
  		}
  		totalFolders = totalFolders + 1;
  		contentMapFlag = true;
	});
	
	if(totalFolders > 3)
    {
    	var countSite = totalFolders - 2;
    	var count = 0;
    	$("span[id$=ctl00_PlaceHolderPageTitleInTitleArea_ContentMap] span a").each(function(){
    		if(count > 1)
    		{
    			if(count < countSite)
    			{
    				$(this).hide();
   		    		$(this).parent().next("span").css('display', 'none');
    			}
    			if(count === countSite)
    			{
    				$(this).parent().text("..");
    			}
    		}
    		count = count + 1;
    	});
   		
    }
	
	var entryTitle = $('span#ctl00_PlaceHolderPageTitleInTitleArea_ContentMap span.ms-sitemapdirectional:last-child').text().trim();
	if (entryTitle.length > 50) {
		  var chopCharacter = entryTitle.substring(0,50);
		  $('span#ctl00_PlaceHolderPageTitleInTitleArea_ContentMap span.ms-sitemapdirectional:last-child').text(chopCharacter);
	}
	
	if(fullControlURLNode != '-' && contentMapFlag == false && fullControlFlag == false)
   	{
		var entryTitle = $('span#DeltaPlaceHolderPageTitleInTitleArea').text().trim();
		if (entryTitle.length > 0) {
			  $('span#DeltaPlaceHolderPageTitleInTitleArea').text(entryTitle);
		}
	}
	
    if(fullControlFlag == true)
    {
   		$("#searchInputBox").css("display","");
    }
}
function readFile(rootSite,fullControlURLNode ,fullControlFlag   ) {
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
    	
    	$("span[id$=ctl00_siteMapPath] span a").each(function(){
    		if($(this).attr('href').indexOf(rootSite) === -1)
    		{
    			rootCount = rootCount + 1;
    		}
    		else
    		{
    			$("#ctl00_onetidProjectPropertyTitleGraphic").attr("href", $(this).attr('href'));
    		}
    	});
    	
    	var loopCount = 0;
		$("span[id$=ctl00_siteMapPath] span a").each(function(){
			if(loopCount < rootCount)
			{
				$(this).hide();
   	   		    $(this).parent().next("span").css('display', 'none');
			}
			loopCount = loopCount + 1;
    	});
    	
    	 var totalSite = 0;
	$("span[id$=ctl00_siteMapPath] span a").each(function(){
   		if($(this).attr('href').indexOf(fullControlURLNode) != -1){
   			$("#ctl00_onetidProjectPropertyTitleGraphic").attr("href", $(this).attr('href'));	
		}
		
		if(fullControlURLNode != '-' && fullControlFlag == false)
		{
			$(this).hide();
   		    $(this).parent().next("span").css('display', 'none');
   		    $('#rtArrow').css("display","none");
		}
		else
    	{
			var entryTitle = $(this).text().trim();
  			if (entryTitle.length > 50) {
  			  var chopCharacter = entryTitle.substring(0,50);
  			  $(this).text(chopCharacter);
  			}
  		}

  		totalSite = totalSite + 1;
   	});
	
    if(totalSite > 3 /*&& fullControlURLNode == '-' && fullControlFlag == true*/)
    {
    	var countSite = totalSite - 3;
    	var count = 0;
    	$("span[id$=ctl00_siteMapPath] span a").each(function(){
    		if(count != 0)
    		{
    			if(count < countSite)
    			{
    				$(this).hide();
   		    		$(this).parent().next("span").css('display', 'none');
    			}
    			if(count === countSite)
    			{
    				$(this).parent().text("..");
    			}
    		}
    		count = count + 1;
    	});
   		
    }
    
    var contentMapFlag = false;
    var totalFolders = 0;
    $("span[id$=ctl00_PlaceHolderPageTitleInTitleArea_ContentMap] span a").each(function(){
    	if(totalFolders == 0)
    	{
    		$(this).hide();
    		$(this).parent().next("span").css('display', 'none');
    	}
    	
    	if(fullControlURLNode != '-' && fullControlFlag == false)
		{
			$(this).hide();
   		    $(this).parent().next("span").css('display', 'none');
   		    $('#rtArrow').css("display","none");
		}
		else
    	{
			var entryTitle = $(this).text().trim();
  			if (entryTitle.length > 50) {
  			  var chopCharacter = entryTitle.substring(0,50);
  			  $(this).text(chopCharacter);
  			}
  		}
  		totalFolders = totalFolders + 1;
  		contentMapFlag = true;
	});
	
	if(totalFolders > 3)
    {
    	var countSite = totalFolders - 2;
    	var count = 0;
    	$("span[id$=ctl00_PlaceHolderPageTitleInTitleArea_ContentMap] span a").each(function(){
    		if(count > 1)
    		{
    			if(count < countSite)
    			{
    				$(this).hide();
   		    		$(this).parent().next("span").css('display', 'none');
    			}
    			if(count === countSite)
    			{
    				$(this).parent().text("..");
    			}
    		}
    		count = count + 1;
    	});
   		
    }
	
	var entryTitle = $('span#ctl00_PlaceHolderPageTitleInTitleArea_ContentMap span.ms-sitemapdirectional:last-child').text().trim();
	if (entryTitle.length > 50) {
		  var chopCharacter = entryTitle.substring(0,50);
		  $('span#ctl00_PlaceHolderPageTitleInTitleArea_ContentMap span.ms-sitemapdirectional:last-child').text(chopCharacter);
	}
	
	if(fullControlURLNode != '-' && contentMapFlag == false && fullControlFlag == false)
   	{
		var entryTitle = $('span#DeltaPlaceHolderPageTitleInTitleArea').text().trim();
		if (entryTitle.length > 0) {
			  $('span#DeltaPlaceHolderPageTitleInTitleArea').text(entryTitle);
		}
	}
	
    if(fullControlFlag == true)
    {
   		$("#searchInputBox").css("display","");
    }
	var checkduplicate= $(".breadcrumbCurrent").html();
					$(".ms-sitemapdirectional").each(function(an){
						if($(this).html()==checkduplicate&&$(location).attr('href').indexOf('_layouts/15/osssearchresults.aspx')==-1)
						{
						$(this).css('display','none');
						$(this).parent().next("span").css('display', 'none');

					}
					});
					$("#navigation").show();

    }

    function errorHandler() {
    
    subsiteAsRootsite("-",fullControlURLNode ,fullControlFlag);
     var checkduplicate= $(".breadcrumbCurrent").html();
					$(".ms-sitemapdirectional").each(function(an){
						if($(this).html()==checkduplicate&&$(location).attr('href').indexOf('_layouts/15/osssearchresults.aspx')==-1)
						{
						$(this).css('display','none');
						$(this).parent().next("span").css('display', 'none');
						}
					});
					if($('#DeltaPlaceHolderPageTitleInTitleArea').html().trim()==checkduplicate)
						{
							$('#DeltaPlaceHolderPageTitleInTitleArea').html("Home");
							
						}
$("#navigation").show();
       
    }
    //$("#navigation").show();
}