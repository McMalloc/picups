var app = app || {};

$(function() {
	app.reqPayload = [];

	$("#dl-btn").click(function() {
		$(".proc-form").each(function() {
			var idx = this.dataset.idx;
			var format = $("[name='format-"+idx+"']:checked").val();
			app.reqPayload.push({
				thresholded: $("[name='thresholded-"+idx+"']").is(":checked"),
				format: format === undefined ? "jpeg" : format,
				name: $(".doc-name[data-idx='"+idx+"']").text(),
				url: this.dataset.url
			});
		});

		$.ajax({
			url: "/getimages",
			//contentType: "application/json",
			type: "post",
			data: JSON.stringify(app.reqPayload)
		}).done(function(res) {
			window.location = res;
		});
	});


	$(".close-btn").click(function() {
		$("#tile-" + this.dataset.idx).attr("data-ignore", "1");
		$(".ignored[data-idx='"+this.dataset.idx+"']").removeClass("dontdisplay");
	});
	$(".ignored").click(function() {
		$("#tile-" + this.dataset.idx).attr("data-ignore", "0");
		$(".ignored[data-idx='"+this.dataset.idx+"']").addClass("dontdisplay");
	});

	$(".bw-check").click(function() {
		var $this = $(this);

		var imgCont = $("#"+$this.attr("data-preview"));
		imgCont.addClass("loading");

		$.post("/switch_thumb", {
			url: this.parentElement.parentElement.dataset.url,
			thumb_url: this.dataset.thumbtarget,
			thresholded: function() {
				return $this.is(':checked');
			}()
		}, function(res) {
			imgCont.find("img").attr("src", res + "?" + new Date().getTime());
			imgCont.removeClass("loading");
		})
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