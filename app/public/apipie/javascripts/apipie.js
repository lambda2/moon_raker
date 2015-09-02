$(document).ready(function() {
  if (typeof prettyPrint == 'function') {
    $('pre.ruby').addClass('prettyprint lang-rb');
    prettyPrint();
  }

  if ($("#page-menu").length > 0) {
    var active = $("body").attr("data-active")
    var menu = $("<ul id='local-menu' class='nav' role='tablist'></ul>")

    $("h2[id]").each(function(){
      menu.append("<li><a href='#" + $(this).attr("id") + "'>" + $(this).html() + "</a></li>")
    });

    $("#page-menu li.link-to-" + active).after(menu)
    $('body').scrollspy({ target: '#page-menu' })
  }
});