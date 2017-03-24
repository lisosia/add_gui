var allowAjax = true;

jQuery(function($) {
    $('#form-ajax').submit( function(ev) {
	if( ! allowAjax ){ alert('prevent double'); return false; }
	allowAjax = false;
	console.log('submit begins');
	ev.preventDefault();
	var $form = $(this);
	var $button = $form.find('button');

	$.ajax({
	    async: false,
	    url: $form.attr('action'),
	    type: $form.attr('method'),
	    data: $form.serialize(),
	    dataType: 'text',
	    timeout: 600000,

	    beforeSend: function(xhr, settings) {
		$button.attr('disabled', true);
	    },

	    complete: function(xhr, textStatus) {
		$button.attr('disabled', false);
		allowAjax = true;
	    },

	    success: function( result, textStatus, xhr ){
		var $res = $('#result');
		$res.text( result );
	    },

	    error: function(xhr, textStatus, error) {
		console.log('submit failed');
		alert( 'error' )
		// var $res = $('#result');
		// $res.text( "ajax post Failed: " + error);
	    }

	})
	
	//prevent
	return false;
    });

});
