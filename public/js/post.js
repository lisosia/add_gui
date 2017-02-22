jQuery(function($) {
    $('#form-ajax').submit( function(ev) {
	console.log('debug');
	ev.preventDefault();
	var $form = $(this);
	var $button = $form.find('button');

	$.ajax({
	    url: $form.attr('action'),
	    type: $form.attr('method'),
	    data: $form.serialize(),
	    dataType: 'text',
	    timeout: 120000,

	    beforeSend: function(xhr, settings) {
		$button.attr('disabled', true);
	    },

	    complete: function(xhr, textStatus) {
		$button.attr('disabled', false);
	    },

	    success: function( result, textStatus, xhr ){
		var $res = $('#result');
		$res.text( result );
	    },

	    error: function(xhr, textStatus, error) {
		console.log('failed');
		var $res = $('#result');
		$res.text( "ajax post Failed: " + error);
	    }

	})

    });

});
