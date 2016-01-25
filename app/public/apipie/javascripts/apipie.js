$(document).ready(function() {
  if (typeof prettyPrint == 'function') {
    $('pre.ruby').addClass('prettyprint lang-rb');
    prettyPrint();
  }

  $("[data-trigger]").click(function(e) {
    target = $(this).attr("data-trigger");
    $("[" + target + "='true']").toggleClass("invisible");
    content = $(this).html();
    if (content.search("Hide") >= 0)
    {
      $(this).html(content.replace("Hide", "Show"));
    }
    else if (content.search("Show") >= 0)
    {
      $(this).html(content.replace("Show", "Hide"));
    }
  });

  if ($("#page-menu").length > 0) {
    var active = $("body").attr("data-active")
    var menu = $("<ul id='local-menu' class='nav' role='tablist'></ul>")

    $("h2[id]").each(function(){
      menu.append("<li><a href='#" + $(this).attr("id") + "'>" + $(this).html() + "</a></li>")
    });

    $("#page-menu li.link-to-" + active).append(menu)
    $('body').scrollspy({ target: '#page-menu' })
  }
});