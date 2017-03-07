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
	    dataType: 'json',
	    timeout: 600000,

	    beforeSend: function(xhr, settings) {
		$button.attr('disabled', true);
		$('#result').text( 'submitted' );
	    },

	    complete: function(xhr, textStatus) {
		$button.attr('disabled', false);
	    },

	    success: function( result, textStatus, xhr ){
		var $res = $('#result');
		if( result['success'] ){
		    $res.text( 'Success : ' );
		    $('<a href="' + result['link'] + '">link to graph</a>').appendTo( $res );
		}else{
		    $res.text( "Failed : " + result['msg'] )
		}
	    },

	    error: function(xhr, textStatus, error) {
		console.log('failed. ' + typeof(error) );
		var $res = $('#result');
		$res.text( "ajax post Failed: " + error + ' : ' + textStatus);
	    }

	})

    });

});
