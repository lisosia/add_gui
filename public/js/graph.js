jQuery(function($) {
    $('#remake').submit(function(ev){
	ev.preventDefault();
	
	$.post({
	    type: 'POST',
	    url: '#',
	    timeout: 1200000,
	    data: { slide : $('#slide').val() },
	    success: function success(data){
		// force reload
		var d = new Date();
		var src = $('#img').attr('src');
		$('#img').attr( src + '?' + d );
		console.log('image reloaded');
	    }
	});

	return false;
    });

});