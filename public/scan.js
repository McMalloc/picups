var app = app || {};

$(function() {

	app.batchcount = 0;

	$('.mod-nr').click(function(event) {
		var $e = $("[name='batchcount']");
		var method = event.target.parentElement.dataset.mod;
		var oldvar = parseInt($e.attr("value"));
		if (method === "inc") {
			$e.attr("value", oldvar +1);
		} else if (method === "dec" && oldvar > 1) {
			$e.attr("value", oldvar -1);
		}
	});

	$('#scanform').submit(function () {
		var self = this;
		$(".status-cont").css("opacity", 1);
		$(".spinner").removeClass("dontdisplay");
		if ((self[1].value > 0) && (self[1].value < 100)) {
			app.batchcount = parseInt(self[1].value);
		} else {
			app.batchcount = 1;
		}
		$.post("scanimage", {
			name: self[0].value,
			batchcount: self[1].value,
			dpi: self[2].value
		});

		app.queryProgress("progress");

		// cancel native request processing
		return false;
	});

	app.queryProgress = function(url) {
		var interval = setInterval(function() {
			$.get(url, {cache: false}).success(function(data) {

				if (data.progress > 0) {
					$("#progress-bar").css("width", data.progress+"%");
				}

				$("#progress").html(data.html);

				if (data.progress === 100) {
					app.batchcount--;
					if (app.batchcount === 0) {
						clearInterval(interval);
						$(".spinner").addClass("dontdisplay");
						$.get("preview", function(data) {
							$("#preview").html(data);
						});
						//setTimeout(function() {
						//	window.location.pathname = "/scannedfiles"
						//}, 500)
					}

				}
			});
		}, 800);
	};
});