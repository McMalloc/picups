var app = app || {};

$(function() {
	app.ScanView = Backbone.View.extend({
		initialize: function(){
		}
	});

	app.scanview = new app.ScanView();

	app.batchcount = 0;

	$('#scanform').submit(function () {
		var self = this;
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

		return false;
	});

	app.queryProgress = function(url) {
		$("#progress").text("Scanner wärmt auf");
		var progressregex = new RegExp(/\d+.\d+%/g);
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
						setTimeout(function() {
							window.location.pathname = "/scannedfiles"
						}, 500)
					}

				}
			});
		}, 500);
	};
});