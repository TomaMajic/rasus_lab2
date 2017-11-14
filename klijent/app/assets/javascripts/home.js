$(document).on('click', '#new-senzor',function() {
	var sensor_num = $('#sensor-num').val();

	if(sensor_num != '') {
		console.log('novi: ', sensor_num);
		window.open('/home/senzor?sensor_number='+sensor_num)
	} else {
		alert('Fali ti broj');
	}	
});
