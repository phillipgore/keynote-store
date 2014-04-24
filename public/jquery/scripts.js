$(document).ready(function() {

	if( /Android|webOS|iPhone|iPad|iPod|BlackBerry/i.test(navigator.userAgent) ) {
		var mobile = true
	}

	var video = $('video')[0];
	
	$('.video_controls a, video, .video_poster').on('click', function(e) {
		e.preventDefault();
		if ($('.video_controls a').hasClass('active_link')) {
			video.pause();
			$('.video_controls a').removeClass('active_link');
		}
		else {
			$(video).load();
			$('.video_poster').fadeOut('fast');
			video.play();
			$('.video_controls a').addClass('active_link');
		}
	});
	
	$(window).on('resize', function() {
		if (mobile === true) {
			var vid_w = $('.video_poster').width();
			var vid_h = $('.video_poster').height();
			$(video).width(vid_w).height(vid_h);
		}
	});
	
	$(video).on('ended', function() {
		$('.video_poster').fadeIn('fast');
		$('.video_controls a').removeClass('active_link');
		$('.video_scrubber').fadeOut(function() {
			$(this).css('marginLeft', 0).fadeIn().removeAttr('style');
		});
	});
	
	$(video).on('load', function() {
		if (mobile === true) {
			var vid_w = $('.video_poster').width();
			var vid_h = $('.video_poster').height();
			$(this).width(vid_w).height(vid_h);
		}
	});
	
	$('.video_scrubber').on('mousedown', function(e) {
		e.preventDefault();
		video.play();
		video.pause();
		var trackPos = $('.video_track').offset();
		var scrubberPos = $(this).offset();
		var trackPosLeft = trackPos.left;
		var scrubberPosLeft = scrubberPos.left;
		var cursorOffset = e.pageX - scrubberPosLeft;
		var trackScrubWidth = parseInt($('.video_track').outerWidth()) - parseInt($(this).outerWidth());
		$('body').on('mousemove', function(e) {
			e.preventDefault();
			$('.video_scrubber').addClass('active_scrubber');
			var newLeftMargin = (e.pageX - cursorOffset) - trackPosLeft;
			if (newLeftMargin === trackScrubWidth) {
				$('.video_poster').show();
			}
			if (newLeftMargin > trackScrubWidth) {
				$('.video_poster').hide();
				$('.video_scrubber').removeAttr('style').css('marginLeft', trackScrubWidth);
			}
			if (newLeftMargin < 0) {
				$('.video_poster').show();
				$('.video_scrubber').removeAttr('style').css('marginLeft', 0);
			}
			if (newLeftMargin < trackScrubWidth && newLeftMargin > 0) {
				$('.video_poster').hide();
				$('.video_scrubber').removeAttr('style').css('marginLeft', newLeftMargin);
			}
			if ($('.video_scrubber').hasClass('active_scrubber')) {
				var updateScrubberPosLeft = parseInt($('.video_scrubber').css('marginLeft'));
				var updateTrackScrubWidth = parseInt($('.video_track').outerWidth()) - parseInt($('.video_scrubber').outerWidth());
				var newVideoTime = (updateScrubberPosLeft / updateTrackScrubWidth) * video.duration;
				video.currentTime = newVideoTime;
			}
		});
	});
	
	$('.video_track').on('click', function(e) {
		var trackPos = $('.video_track').offset();
		var trackPosLeft = trackPos.left;
		var newScrubberPos = e.pageX  - trackPosLeft - parseInt($('.video_scrubber').outerWidth());
		$('.video_scrubber').removeAttr('style').css('marginLeft', newScrubberPos);
		var updateScrubberPosLeft = parseInt($('.video_scrubber').css('marginLeft'));
		var updateTrackScrubWidth = parseInt($('.video_track').outerWidth()) - parseInt($('.video_scrubber').outerWidth());
		var newVideoTime = (updateScrubberPosLeft / updateTrackScrubWidth) * video.duration;
		video.currentTime = newVideoTime;
		var trackScrubWidth = parseInt($('.video_track').outerWidth()) - parseInt($('.video_scrubber').outerWidth());
		if (newScrubberPos < trackScrubWidth && newScrubberPos > 0) {
			$('.video_poster').hide();
		}
		else {
			$('.video_poster').show();
		}
		if ($('.video_controls a').hasClass('active_link')) {
			$('.video_poster').fadeOut('fast');
			video.play();
		}
	});
	
	$(video).on('timeupdate', function() {
		var percentComplete = video.currentTime / video.duration;
		var trackScrubWidth = parseInt($('.video_track').outerWidth()) - parseInt($('.video_scrubber').outerWidth());
		var newScrubberPos = percentComplete * trackScrubWidth;
		$('.video_scrubber').removeAttr('style').css('marginLeft', newScrubberPos);
	});	
	
	$(window).on('mouseup', function() {
		$('body').off('mousemove');
		$('.video_scrubber').removeClass('active_scrubber');
		if ($('.video_controls a').hasClass('active_link')) {
			$('.video_poster').fadeOut('fast');
			video.play();
		}
	});
	
	$('#admin .delete').on('click', function(e) {
		e.preventDefault();
		var action = $(this).attr('href');
		var response = confirm("This action is permanent.\nAre you sure you want to delete?");
		if (response === true) {
		  window.location = action;
		  }
	});
	
	$('#print').on('click', function(){
		var url = $(this).attr('href');
		window.open(url, width=612);
		return false;
	});
	
	
	
	
	
	
	
	

});