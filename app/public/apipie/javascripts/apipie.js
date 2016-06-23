
$(document).ready(function() {
  if (typeof prettyPrint == 'function') {
    $('pre.ruby').addClass('prettyprint lang-rb');
    prettyPrint();
  }

  if ($("[data-restricted='true']").length > 0)
  {
    if (localStorage.getItem('data-restricted') == 'true')
    {
      $("[data-restricted='true']").toggleClass("invisible");
      $("[data-trigger='data-restricted']").html($("[data-trigger='data-restricted']").html().replace("Show", "Hide"));
    }
  }

  $("[data-trigger]").click(function(e) {
    var target = $(this).attr("data-trigger");
    var localStorageTarget = target;

    $("[" + target + "='true']").toggleClass("invisible");
    content = $(this).html();
    if (content.search("Hide") >= 0)
    {
      $(this).html(content.replace("Hide", "Show"));
      localStorage.setItem(localStorageTarget, null);
    }
    else if (content.search("Show") >= 0)
    {
      $(this).html(content.replace("Show", "Hide"));
      localStorage.setItem(localStorageTarget, "true");
    }
  });

  if ($("#page-menu").length > 0 && window.innerWidth >= 1200) {
    var active = $("body").attr("data-active")
    var menu = $("<ul id='local-menu' class='nav' role='tablist'></ul>")

    $("h2[id]").each(function(){
      menu.append("<li><a href='#" + $(this).attr("id") + "'>" + $(this).html() + "</a></li>")
    });

    $("#page-menu li.link-to-" + active).append(menu)
    $('body').scrollspy({ target: '#page-menu' })
  }

});
