jQuery(function($) {

    var allowAjax = true;
    var endflag = false;
    var submit_func = function(ev) {
	ev.preventDefault();
	if( ! allowAjax ){ alert('prevent double'); return false; }
	console.log('submit begins');
	var $form = $(this);
	var $button = $form.find('button');

	$.ajax({
	    async: false,
	    url: $form.attr('action'),
	    cache: false,
	    type: $form.attr('method'),
	    data: $form.serialize(),
	    dataType: 'json',
	    timeout: 600000,

	    beforeSend: function(xhr, settings) {
		$button.attr('disabled', true);
	    }
	}).done(function(data){	
	    var $res = $('#result');
	    var status = data['status'];
	    var strinfo = JSON.stringify(data);
	    var $text = $res.val()
	    $res.val( $text + strinfo + "\n" );
	    if( status == 'done' || status == 'error' ){
		endflag = true;
		$res.val( $res.val() + "_____ENDED_____\n" );
	    }
	}).fail( function(jqHHR, textStatus, errorThrown ){
	    console.log('error while ajax');
	    var $res = $('#result');
	    var $text = $res.val()
	    $res.val( $text + textStatus + "\n" );
	}).always(function(){
	    $button.attr('disabled', false);
	    allowAjax = true;
	    scrollToBottom();
	})
	
	//prevent
	return false;
    }

    $('#form-ajax').submit( submit_func );

    var max = 100;
    var sleep = 20 * 1000;
    var submit_loop = function(count){
	if( ! endflag && count > 0 ){
	    console.log( count);
	    $('#form-ajax').submit();
	    setTimeout( function(){ submit_loop( count -1 );} , sleep );
	}else{
	    console.log('loop end');
	}
    };

    submit_loop( max );


    //whien changed; scroll to bottom
    function scrollToBottom(){
	var ta = $('#result');
	ta.scrollTop( ta[0].scrollHeight - ta.height() );
    };

});
