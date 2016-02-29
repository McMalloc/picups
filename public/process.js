var app = app || {};

$(function() {
	$(".dl-pdf").click(function() {
		app.requestfile(this.dataset.idx, "pdf", "text");
	});
	$(".dl-jpeg").click(function() {
		app.requestfile(this.dataset.idx, "jpeg", "color");
	});

	$(".table-date").each(function() {
		this.textContent = moment(this.textContent).fromNow();
	});

	app.requestfile = function(idx, format, type) {
		var $a = $("a[data-idx='" + idx + "']");
		  $.get("getimage", {
			  format: format,
			  type: type,
			  name: $a.text(),
			  file: "public/" + $a.attr("href")
		  }, function(data) {
			  window.location.pathname = data;
		  })
  	}
});