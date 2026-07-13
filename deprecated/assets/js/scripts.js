/* GLOBALS */
let map; //mapboxgl map
let mapPop; //mapboxgl popup
let mapHov; //mapboxgl popup
let pwsData = {};  //full dataset populated from map layers 
let mergedData;  //full dataset as single geojson
let combinedFilter = [];  //array of pwsids

$(document).ready(function(){

	$("#download-geojson-request").submit(function(e) {
		
		e.preventDefault();    
		var formData = new FormData(this);
		$.ajax({
			url: 'download_geojson.php',
			type: 'POST',
			data: formData,
			dataType: "json",
			success: function (data) {
				downloadGeoJSON(JSON.stringify(data), 'geo_download.geojson');
			},
			cache: false,
			contentType: false,
			processData: false
		});
	});



	$('.btn-export').on('click', function(){
		if($('#file-csv').is(':checked'))
			exportDataTableToCSV('#data-table', 'datatable_export.csv');
		else if($('#file-geojson').is(':checked'))
			exportDataTableToGeoJSON();
	});

	$('#boil-water-notices').on('click', function(){
		if($('#boil-water-notices').is(':checked'))
			$('.bwn-content-wrapper').show();
		else
			$('.bwn-content-wrapper').hide();
	});


	$('.input-number').on('focus', function(){
		$(this).val($(this).val().replaceAll(',',''));
		//$(this).prop('type','number');
	});
	$('.input-number').on('blur', function(){
		//$(this).prop('type','text');
		//$(this).val(parseFloat($(this).val()).toLocaleString('en-US'));
		labelId = $(this).prop('id').replace('Input','Label');
		$('#'+labelId).html(parseFloat($(this).val()).toLocaleString('en-US'));
	});
	
	$('li:has(input[type="checkbox"])').on('click', function (e) {
		if ($(e.target).is('label')) return;
		
		if ($(e.target).is('input')) return;

		const $checkbox = $(this).find('input[type="checkbox"]');
		$checkbox.trigger('click');
	});

	$('li:has(input[type="radio"])').on('click', function (e) {
		if ($(e.target).is('label')) return;
		
		if ($(e.target).is('input')) return;

		const $checkbox = $(this).find('input[type="radio"]');
		$checkbox.trigger('click');
	});


	$('#type-deselect-all').on('click', function(){
		if($(this).is(':checked')){
			$('.checkbox-type').prop('checked', true);
			$('#type-deselect-all-txt').text('Deselect all');
		} else {
			$('.checkbox-type').prop('checked', false);
			$('#type-deselect-all-txt').text('Select all');
		}
	});

	$('#48-zoom').on('click', function(){
		//clear geo filter
		$('.mapboxgl-ctrl-geocoder--input').val('');
		$('.mapboxgl-ctrl-geocoder--icon-close').trigger('click');
	});

	$('#ak-zoom').on('click', function(){
		map.flyTo({
			center: [-149.50426385578243, 61.34196679301752], //alaska center
			zoom: 4.9
		});
		map.once('idle', function() {
			const center = map.getCenter();
			map.fire('click', { lngLat: center });
			map.once('idle', function() {
				map.flyTo({zoom:5,duration:3600});
			});
		});
	});

	$('#hi-zoom').on('click', function(){
		map.flyTo({
			center: [-157.85567600000002, 21.304547000000014], //hawaii center
			zoom: 4.9
		});
		map.once('idle', function() {
			const center = map.getCenter();
			map.fire('click', { lngLat: center });
			map.once('idle', function() {
				map.flyTo({zoom:6,duration:3600});
			});
		});
	});

	$('.container-filter-count').hide();

	$('.map-checkbox').on('click', function(){
		if($(this).is(':checked')){
			$('#color-bar-'+$(this).val()).slideDown();
			$('.map-checkbox').not(this).prop('checked', false);  //deselect any other checkboxes that are checked
			updateMap($(this).prop('id').replace('map-',''));
		} else {
			$('#color-bar-'+$(this).val()).slideUp();
			map.setPaintProperty("pws", "fill-color", "rgb(78, 163, 36)");
		}
	});

	$('.btn-clear-filters').on('click', function(){
		let counter = 0;
			do {
				counter++;
				$("#container-menu-" + counter).hide();
				$("#container-menu-btn-" + counter).removeClass("active");
			} while (counter < 11);
		$('#loading-mask').show();
		$('.toggle').prop('checked', false);
		$('.container-filter').removeClass('active').addClass('hidden').slideUp();
		setTimeout(() => {
			//console.log("updating filter from clear filter click");
			updateFilter();
			$('#loading-mask').hide();
		},0);		
	});

	$('.btn-apply-filters').on('click', function(){
		let counter = 0;
		do {
			counter++;
			$("#container-menu-" + counter).hide();
			$("#container-menu-btn-" + counter).removeClass("active");
		} while (counter < 11);
		$('#loading-mask').show();
		//let now = new Date();
		//console.log('about to start filter:', now.toString());
		setTimeout(() => {
			//console.log("updating filter from apply filter click");
			//updateFilter();
			$('#loading-mask').hide();
			//let now = new Date();
			//console.log('all done with filter:', now.toString());
		},0);		
	});

	
	$('.toggle').on('click', function(){
		$('#loading-mask').show();
		setTimeout(() => {
			//console.log("updating filter from toggle click");
			updateFilter();
			$('#loading-mask').hide();
		},0);		
	});

	//for select boxes
	$('.toggle-select').on('change', function(){
		$('#loading-mask').show();
		setTimeout(() => {
			//console.log("updating filter from toggle select change");
			updateFilter();
			$('#loading-mask').hide();
		},0);		
	});

	mapboxgl.accessToken = 'pk.YOUR_MAPBOX_ACCESS_TOKEN'; // placeholder — real token removed (legacy reference code, not run)
	map = new mapboxgl.Map({
		container: 'map', // container ID
		style: 'mapbox://styles/cntgrid/cke9g093i0b3p1amudlyqay3t', // style URL
		center: [-97.6, 40.27], 
		zoom: 2 // starting zoom
	});

	// disable map rotation using right click + drag
    map.dragRotate.disable();

    map.on('load', function () {

        const geocoder = new MapboxGeocoder({
            accessToken: mapboxgl.accessToken,
            mapboxgl: mapboxgl,
            marker: false,
			flyTo: false,
			countries: 'US',
			placeholder: 'Search map...'
        });
        map.addControl(geocoder,'top-left');
		// disable map rotation using touch rotation gesture
    	map.touchZoomRotate.disableRotation();

		const geolocateCtrl = new mapboxgl.GeolocateControl({fitBoundsOptions: {maxZoom: 10}, showUserLocation: false});
		
        map.addControl(new mapboxgl.NavigationControl({showCompass: false}),'top-left');
		

		geolocateCtrl.on('geolocate', function(e) {
    		//const userLocation = e.coords;
			map.once('idle', function() {
				const center = map.getCenter();

				//project to use (pixel xy coordinates instead of lat/lon for WebGL)
	        	const geolocate_point = map.project([center.lng, center.lat]);

				/*
				const placeFeatures = map.queryRenderedFeatures(geolocate_point, {layers: ['places']});
				let pwsids;
				if(placeFeatures.length>0) {
					pwsids = placeFeatures.length>0 ? JSON.parse(placeFeatures[0].properties.place_pwsids) : [];
					map.setFilter('place_filter', ['in', 'geoid', placeFeatures.length>0 ? placeFeatures[0].properties.geoid : '']);
					//$('.mapboxgl-ctrl-geocoder--input').val(placeFeatures[0].properties.name);
					geoFilterName = placeFeatures[0].properties.name;
					geoFilterId = placeFeatures[0].properties.geoid;
					geoFilterType = 'place';
				} else {
					const countyFeatures = map.queryRenderedFeatures(geolocate_point, {layers: ['counties']});
					pwsids = countyFeatures.length>0 ? JSON.parse(countyFeatures[0].properties.county_pwsids) : [];
					map.setFilter('counties_filter', ['in', 'geoid', countyFeatures.length>0 ? countyFeatures[0].properties.geoid : '']);
					//$('.mapboxgl-ctrl-geocoder--input').val(countyFeatures[0].properties.name);
					geoFilterName = countyFeatures[0].properties.name;
					geoFilterId = countyFeatures[0].properties.geoid;
					geoFilterType = 'county';
				}
				*/
				
				const features = map.queryRenderedFeatures(geolocate_point, {layers: ['states']});
				if(features.length>0){
					pwsids = features.length>0 ? JSON.parse(features[0].properties.state_pwsids) : [];
					map.setFilter('states_filter', ['in', 'geoid', features.length>0 ? features[0].properties.geoid : '']);
					geoFilterName = features[0].properties.name;
					geoFilterId = features[0].properties.geoid;
					geoFilterType = 'state';

					pwsFilterGeo = pwsids;
					$('#loading-mask').show();
					setTimeout(() => {
						//console.log("updating filter from geolocate");
						updateFilter();
						$('#loading-mask').hide();
					},0);
				}
			});

		});

    	//map.addControl(new mapboxgl.FullscreenControl(),'bottom-left');
        geocoder.on('result', function(ev) {
			//console.log(ev.result);

			map.setFilter('states_filter', ['in', 'geoid', '']);
			map.setFilter('counties_filter', ['in', 'geoid', '']);
			map.setFilter('places_filter', ['in', 'geoid', '']);
			pwsFilterGeo = [];

			let z=10;
		
			if(ev.result.place_type[0] == 'region'){ //states
				z=5;
			}
			else if(ev.result.place_type[0] == 'district'){ //counties
				z=7;
			}
			else if(ev.result.place_type[0] == 'place'){ //places
				z=8;
			}

            const coordinates = ev.result.geometry.coordinates;

			//project to use (pixel xy coordinates instead of lat/lon for WebGL)
        	const geocoder_point = map.project([ev.result.center[0], ev.result.center[1]]);
			
			//console.log(z, !map.isPointOnSurface(geocoder_point))
			//for state, county or place searches, only flyto if the point is not in the current map view
			if(z==10 || !map.isPointOnSurface(geocoder_point))
				map.flyTo({
					center: coordinates,
					zoom: z
				});

			map.once('idle', function() {
				//project to use (pixel xy coordinates instead of lat/lon for WebGL)
	        	const geocoder_point = map.project([ev.result.center[0], ev.result.center[1]]);

				if(ev.result.place_type[0] == 'region'){ //states
					const features = map.queryRenderedFeatures(geocoder_point, {layers: ['states']});
					const pwsids = features.length>0 ? JSON.parse(features[0].properties.state_pwsids) : [];
					geoFilterName = features.length>0 ? features[0].properties.name : '';
					geoFilterId = features.length>0 ? features[0].properties.geoid : '';
					geoFilterType = features.length>0 ? 'state' : '';
					pwsFilterGeo = pwsids;
					map.setFilter('states_filter', ['in', 'geoid', features.length>0 ? features[0].properties.geoid : '']);
				}
				else if(ev.result.place_type[0] == 'district'){ //counties
					const features = map.queryRenderedFeatures(geocoder_point, {layers: ['counties']});
					const pwsids = features.length>0 ? JSON.parse(features[0].properties.county_pwsids) : [];
					geoFilterName = features.length>0 ? features[0].properties.name : '';
					geoFilterId = features.length>0 ? features[0].properties.geoid : '';
					geoFilterType = features.length>0 ? 'county' : '';
					pwsFilterGeo = pwsids;
					map.setFilter('counties_filter', ['in', 'geoid', features.length>0 ? features[0].properties.geoid : '']);
				}
				else if(ev.result.place_type[0] == 'place'){ //places
					const features = map.queryRenderedFeatures(geocoder_point, {layers: ['places']});
					const pwsids = features.length>0 ? JSON.parse(features[0].properties.place_pwsids) : [];
					geoFilterName = features.length>0 ? features[0].properties.name : '';
					geoFilterId = features.length>0 ? features[0].properties.geoid : '';
					geoFilterType = features.length>0 ? 'place' : '';
					pwsFilterGeo = pwsids;
					map.setFilter('places_filter', ['in', 'geoid', features.length>0 ? features[0].properties.geoid : '']);
				}
				else {  //for any other type, we select the place or county
					const placeFeatures = map.queryRenderedFeatures(geocoder_point, {layers: ['places']});
					let pwsids;
					if(placeFeatures.length>0) {
						pwsids = placeFeatures.length>0 ? JSON.parse(placeFeatures[0].properties.place_pwsids) : [];
						map.setFilter('place_filter', ['in', 'geoid', placeFeatures.length>0 ? placeFeatures[0].properties.geoid : '']);
						//$('.mapboxgl-ctrl-geocoder--input').val(placeFeatures[0].properties.name);
						geoFilterName = placeFeatures[0].properties.name;
						geoFilterId = placeFeatures[0].properties.geoid;
						geoFilterType = 'place';
					} else {
						const countyFeatures = map.queryRenderedFeatures(geocoder_point, {layers: ['counties']});
						pwsids = countyFeatures.length>0 ? JSON.parse(countyFeatures[0].properties.county_pwsids) : [];
						map.setFilter('counties_filter', ['in', 'geoid', countyFeatures.length>0 ? countyFeatures[0].properties.geoid : '']);
						//$('.mapboxgl-ctrl-geocoder--input').val(countyFeatures[0].properties.name);
						geoFilterName = countyFeatures[0].properties.name;
						geoFilterId = countyFeatures[0].properties.geoid;
						geoFilterType = 'county';
					}
					pwsFilterGeo = pwsids;
				}

				locationDependantUpdates();

				$('#loading-mask').show();
				setTimeout(() => {
					//console.log("updating filter from geocoder search");
					updateFilter();
					$('#loading-mask').hide();
				},0);		
				map.fitBounds([[ev.result.bbox[0],ev.result.bbox[1]],[ev.result.bbox[2],ev.result.bbox[3]]], {padding: 40, linear:false, duration:3600});
	        });

        });

		var layers = map.getStyle().layers;
		// Find the index of the first line layer in the map style
		var firstLineId;
		for (var i = 0; i < layers.length; i++) {
			if (layers[i].type === 'line') {
				firstLineId = layers[i].id;
				break;
			}
		}

		map.addSource(
			"wdt",
			{
				"type": "vector",
				"tiles": [window.location.protocol+"//"+window.location.host+window.location.pathname+"wdt_mvt.php?c=0&z={z}&x={x}&y={y}"]
			}
		);

		map.addLayer({
			'id': 'pws_sabs',
			'type': 'circle',
			'source': 'wdt',
			'source-layer': 'pws_sabs',
			//'minzoom': 5,
			'layout':  {
			'visibility': 'visible'
			},
			'paint': {
				'circle-color': 'black',
				'circle-opacity': 0			
			}
		});
		map.addLayer({
			'id': 'pws_cejst',
			'type': 'circle',
			'source': 'wdt',
			'source-layer': 'pws_cejst',
			//'minzoom': 5,
			'layout':  {
			'visibility': 'visible'
			},
			'paint': {
				'circle-color': 'black',
				'circle-opacity': 0			
			}
		});

		map.addLayer({
			'id': 'pws_ejscreen',
			'type': 'circle',
			'source': 'wdt',
			'source-layer': 'pws_ejscreen',
			//'minzoom': 5,
			'layout':  {
			'visibility': 'visible'
			},
			'paint': {
				'circle-color': 'black',
				'circle-opacity': 0			
			}
		});
        
		map.addLayer({
			'id': 'pws_acs',
			'type': 'circle',
			'source': 'wdt',
			'source-layer': 'pws_acs',
			//'minzoom': 5,
			'layout':  {
			'visibility': 'visible'
			},
			'paint': {
				'circle-color': 'black',
				'circle-opacity': 0			
			}
		});

		map.addLayer({
			'id': 'pws_cvi',
			'type': 'circle',
			'source': 'wdt',
			'source-layer': 'pws_cvi',
			//'minzoom': 5,
			'layout':  {
			'visibility': 'visible'
			},
			'paint': {
				'circle-color': 'black',
				'circle-opacity': 0			
			}
		});

		map.addLayer({
			'id': 'pws_viols',
			'type': 'circle',
			'source': 'wdt',
			'source-layer': 'pws_viols',
			//'minzoom': 5,
			'layout':  {
			'visibility': 'visible'
			},
			'paint': {
				'circle-color': 'black',
				'circle-opacity': 0			
			}
		});

		map.addLayer({
			'id': 'pws_svi',
			'type': 'circle',
			'source': 'wdt',
			'source-layer': 'pws_svi',
			//'minzoom': 5,
			'layout':  {
			'visibility': 'visible'
			},
			'paint': {
				'circle-color': 'black',
				'circle-opacity': 0			
			}
		});

		map.addLayer({
			'id': 'pws_10yr',
			'type': 'circle',
			'source': 'wdt',
			'source-layer': 'pws_10yr',
			//'minzoom': 5,
			'layout':  {
			'visibility': 'visible'
			},
			'paint': {
				'circle-color': 'black',
				'circle-opacity': 0			
			}
		});

 		map.addLayer({
			'id': 'pws_bwn',
			'type': 'circle',
			'source': 'wdt',
			'source-layer': 'pws_bwn',
			//'minzoom': 5,
			'layout':  {
			'visibility': 'visible'
			},
			'paint': {
				'circle-color': 'black',
				'circle-opacity': 0			
			}
		});

 		map.addLayer({
			'id': 'pws_npdes',
			'type': 'circle',
			'source': 'wdt',
			'source-layer': 'pws_npdes',
			//'minzoom': 5,
			'layout':  {
			'visibility': 'visible'
			},
			'paint': {
				'circle-color': 'black',
				'circle-opacity': 0			
			}
		});

		map.addLayer({
			'id': 'pws_funding',
			'type': 'circle',
			'source': 'wdt',
			'source-layer': 'pws_funding',
			//'minzoom': 5,
			'layout':  {
			'visibility': 'visible'
			},
			'paint': {
				'circle-color': 'black',
				'circle-opacity': 0			
			}
		});



  		map.addLayer({
			'id': 'states',
			'type': 'fill',
			'source': 'wdt',
			'source-layer': 'states',
			//'minzoom': 5,
			'layout':  {
			'visibility': 'visible'
			},
			'paint': {
				'fill-color': '#fff',
				'fill-opacity': 0,
				'fill-outline-color': '#eee' 
			}
		},firstLineId);

  		map.addLayer({
			'id': 'counties',
			'type': 'fill',
			'source': 'wdt',
			'source-layer': 'counties',
			//'minzoom': 5,
			'layout':  {
			'visibility': 'visible'
			},
			'paint': {
				'fill-color': '#fff',
				'fill-opacity': 0,
				'fill-outline-color': '#eee' 
			}
		},firstLineId);

		/*
  		map.addLayer({
			'id': 'places',
			'type': 'fill',
			'source': 'wdt',
			'source-layer': 'places',
			'minzoom': 8,
			'layout':  {
			'visibility': 'visible'
			},
			'paint': {
				'fill-color': '#ecf239',
				'fill-opacity': 0.2,
				'fill-outline-color': '#eee' 
			}
		},firstLineId);

  		map.addLayer({
			'id': 'counties_hover',
			'type': 'fill',
			'source': 'wdt',
			'source-layer': 'counties',
			//'minzoom': 5,
			'layout':  {
			'visibility': 'visible'
			},
			'paint': {
				'fill-color': 'rgb(78, 163, 36)',
				'fill-opacity': 0.2,
				'fill-outline-color': '#999' 
			},
			'filter' : ['in', 'geoid', '']
		});

  		map.addLayer({
			'id': 'places_hover',
			'type': 'fill',
			'source': 'wdt',
			'source-layer': 'places',
			//'minzoom': 5,
			'layout':  {
			'visibility': 'visible'
			},
			'paint': {
				'fill-color': 'rgb(78, 163, 36)',
				'fill-opacity': 0.2,
				'fill-outline-color': '#999' 
			},
			'filter' : ['in', 'geoid', '']
		});
		*/

  		map.addLayer({
			'id': 'states_hover',
			'type': 'fill',
			'source': 'wdt',
			'source-layer': 'states',
			//'minzoom': 5,
			'layout':  {
			'visibility': 'visible'
			},
			'paint': {
				'fill-color': 'rgb(78, 163, 36)',
				'fill-opacity': 0.2,
				'fill-outline-color': '#999' 
			},
			'filter' : ['in', 'geoid', '']
		});


  		map.addLayer({
			'id': 'pws',
			'type': 'fill',
			'source': 'wdt',
			'source-layer': 'pws',
			//'minzoom': 5,
			'layout':  {
			'visibility': 'visible'
			},
			'paint': {
				'fill-color': 'rgb(78, 163, 36)',
				'fill-opacity': 0.2,
				//'fill-color': '#ddf',
				//'fill-opacity': .5,
				'fill-outline-color': '#000' 
			}
		},firstLineId);

  		map.addLayer({
			'id': 'pws_hover',
			'type': 'line',
			'source': 'wdt',
			'source-layer': 'pws',
			//'minzoom': 5,
			'layout':  {
			'visibility': 'visible'
			},
			'paint': {
				'line-color': '#000',
				'line-width': {
					'base': 2,
					'stops': [[8, 2.5], [22, 4.5]]
				},
			},
			'filter' : ['in', 'pwsid', '']
		},firstLineId);

        map.addLayer({
			'id': 'pws_outline',
			'type': 'line',
			'source': 'wdt',
			'source-layer': 'pws',
			'minzoom': 8,
			'layout':  {
				'visibility': 'visible'
				},
			'paint': {
				'line-color': '#000',
				'line-width': {
					'base': 1,
					'stops': [[8, 1.5], [22, 3.5]]
				},
				'line-opacity': 1
			}
		});


		map.addLayer({
			'id': 'selected_pws',
			'type': 'line',
			'source': 'wdt',
			'source-layer': 'pws',
			'layout':  {
				'visibility': 'none'
				},
			'paint': {
				'line-color': '#f00',
				'line-width': 2,
				'line-opacity': 1
			},
			'filter' : ['in', 'pwsid', '']
		});

		map.addLayer({
			'id': 'states_filter',
			'type': 'line',
			'source': 'wdt',
			'source-layer': 'states',
			//'minzoom': 5,
			'layout':  {
			'visibility': 'visible'
			},
			'paint': {
				'line-color': '#000', 
				'base': 2,
				'stops': [[8, 2.5], [22, 4.5]]
			},
			'filter' : ['in', 'geoid', '']
		});

  		map.addLayer({
			'id': 'counties_filter',
			'type': 'line',
			'source': 'wdt',
			'source-layer': 'counties',
			//'minzoom': 5,
			'layout':  {
			'visibility': 'visible'
			},
			'paint': {
				'line-color': 'rgb(78, 163, 36)' 
			}, 
			'filter' : ['in', 'geoid', '']
		});

  		map.addLayer({
			'id': 'places_filter',
			'type': 'line',
			'source': 'wdt',
			'source-layer': 'places',
			//'minzoom': 5,
			'layout':  {
			'visibility': 'visible'
			},
			'paint': {
				'line-color': 'rgb(78, 163, 36)' 
			}, 
			'filter' : ['in', 'geoid', '']
		});		


        map.on('mousemove', 'states', function (e) {
            //if(map.getZoom()>= 6)
            //    return;
   
            const props = e.features[0].properties;
			if(geoFilterId != props.geoid){
				map.getCanvas().style.cursor = 'pointer';
	            map.setFilter('states_hover', ['in', 'geoid', props.geoid]);
			}else{
	            map.getCanvas().style.cursor = 'grab';            
	            //map.setFilter('places_hover', ['in', 'geoid', '']);
	            //map.setFilter('counties_hover', ['in', 'geoid', '']);
	            map.setFilter('states_hover', ['in', 'geoid', '']);
			}

        });

        map.on('mouseleave', 'states', function () {
            //if(map.getZoom()>= 6)
            //    return;

			map.getCanvas().style.cursor = 'grab';
			//map.setFilter('places_hover', ['in', 'geoid', '']);
			//map.setFilter('counties_hover', ['in', 'geoid', '']);
			map.setFilter('states_hover', ['in', 'geoid', '']);
        });

        map.on('click', 'states', function (e) {
            //if(map.getZoom()>= 6)
            //    return;

			const props = e.features[0].properties;
			if(geoFilterId != props.geoid){
				//reset all 
				resetByCategory('container-map');

				const pwsids = JSON.parse(props.state_pwsids);
				const bbox = props.bbox.replace('BOX(','').replace(')','').split(',');
				const minlatLng = bbox[0].split(' ');
				const maxlatLng = bbox[1].split(' ');
				if(props.stusps != 'AK' && props.stusps != 'HI')
					map.fitBounds([minlatLng,maxlatLng], {padding: 40, maxZoom: 6, linear:false, duration:3600});
				pwsFilterGeo = pwsids;
				//$('.mapboxgl-ctrl-geocoder--input').val(st.name).focus().trigger('change');
				geoFilterName = props.name;
				geoFilterId = props.geoid;
				geoFilterType = 'state';
				$('.mapboxgl-ctrl-geocoder--input').val(''); //reset geocoder input in case a value exists
	            map.setFilter('pws_hover', ['in', 'pwsid', '']);
	            //map.setFilter('places_hover', ['in', 'geoid', '']);
	            //map.setFilter('counties_hover', ['in', 'geoid', '']);
	            map.setFilter('states_hover', ['in', 'geoid', '']);
				//map.setFilter('places_filter', ['in', 'geoid', '']);  //reset in case 
				//map.setFilter('counties_filter', ['in', 'geoid', '']); //reset in case
				map.setFilter('states_filter', ['in', 'geoid', props.geoid]);
				locationDependantUpdates();

				$('#loading-mask').show();
				setTimeout(() => {
					//console.log("updating filter from state click");
					updateFilter();
					$('#loading-mask').hide();
				},0);
			}	
		});
				

/*
        map.on('mousemove', 'counties', function (e) {
            if(map.getZoom()>= 10 || map.getZoom()<6)
                return;

            const props = e.features[0].properties;
			if(geoFilterId != props.geoid){
				map.getCanvas().style.cursor = 'pointer';
	            map.setFilter('counties_hover', ['in', 'geoid', props.geoid]);
			}else{
	            map.getCanvas().style.cursor = 'grab';            
	            map.setFilter('places_hover', ['in', 'geoid', '']);
	            map.setFilter('counties_hover', ['in', 'geoid', '']);
	            map.setFilter('states_hover', ['in', 'geoid', '']);
			}

        });

        map.on('mouseleave', 'counties', function () {
            if(map.getZoom()>= 10 || map.getZoom()<6)
                return;

			map.getCanvas().style.cursor = 'grab';
			map.setFilter('places_hover', ['in', 'geoid', '']);
			map.setFilter('counties_hover', ['in', 'geoid', '']);
			map.setFilter('states_hover', ['in', 'geoid', '']);
        });

        map.on('click', 'counties', function (e) {
            if(map.getZoom()>= 10 || map.getZoom()<6)
                return;

			const props = e.features[0].properties;
			if(geoFilterId != props.geoid){
				const pwsids = JSON.parse(props.county_pwsids);
				const bbox = props.bbox.replace('BOX(','').replace(')','').split(',');
				const minlatLng = bbox[0].split(' ');
				const maxlatLng = bbox[1].split(' ');
				map.fitBounds([minlatLng,maxlatLng], {padding: 40, maxZoom: 10, linear:false, duration:3600});
				pwsFilterGeo = pwsids;
				//$('.mapboxgl-ctrl-geocoder--input').val(st.name).focus().trigger('change');
				geoFilterName = props.name;
				geoFilterId = props.geoid;
				geoFilterType = 'county';
				$('.mapboxgl-ctrl-geocoder--input').val(''); //reset geocoder input in case a value exists
	            map.setFilter('pws_hover', ['in', 'pwsid', '']);
	            map.setFilter('places_hover', ['in', 'geoid', '']);
	            map.setFilter('counties_hover', ['in', 'geoid', '']);
	            map.setFilter('states_hover', ['in', 'geoid', '']);
				map.setFilter('places_filter', ['in', 'geoid', '']);  //reset in case 
				map.setFilter('counties_filter', ['in', 'geoid', props.geoid]); //reset in case
				map.setFilter('states_filter', ['in', 'geoid', '']);
				$('#loading-mask').show();
				setTimeout(() => {
					//console.log("updating filter from county click");
					updateFilter();
					$('#loading-mask').hide();
				},0);
			}	
		});

        map.on('mousemove', 'places', function (e) {
            if(map.getZoom()<10)
                return;

            const props = e.features[0].properties;
			if(geoFilterId != props.geoid){
				map.getCanvas().style.cursor = 'pointer';
	            map.setFilter('places_hover', ['in', 'geoid', props.geoid]);
			}else{
	            map.getCanvas().style.cursor = 'grab';            
	            map.setFilter('places_hover', ['in', 'geoid', '']);
	            map.setFilter('counties_hover', ['in', 'geoid', '']);
	            map.setFilter('states_hover', ['in', 'geoid', '']);
			}

        });

        map.on('mouseleave', 'places', function () {
            if(map.getZoom()<10)
                return;

			map.getCanvas().style.cursor = 'grab';
            map.setFilter('places_hover', ['in', 'geoid', '']);
			map.setFilter('counties_hover', ['in', 'geoid', '']);
			map.setFilter('states_hover', ['in', 'geoid', '']);
        });

        map.on('click', 'places', function (e) {
            if(map.getZoom()<10)
                return;

			const props = e.features[0].properties;
			if(geoFilterId != props.geoid){
				const pwsids = JSON.parse(props.place_pwsids);
				const bbox = props.bbox.replace('BOX(','').replace(')','').split(',');
				const minlatLng = bbox[0].split(' ');
				const maxlatLng = bbox[1].split(' ');
				map.fitBounds([minlatLng,maxlatLng], {padding: 40, maxZoom: 12, linear:false, duration:3600});
				pwsFilterGeo = pwsids;
				//$('.mapboxgl-ctrl-geocoder--input').val(st.name).focus().trigger('change');
				geoFilterName = props.name;
				geoFilterId = props.geoid;
				geoFilterType = 'county';
				$('.mapboxgl-ctrl-geocoder--input').val(''); //reset geocoder input in case a value exists
	            map.setFilter('places_hover', ['in', 'geoid', '']);
	            map.setFilter('counties_hover', ['in', 'geoid', '']);
	            map.setFilter('states_hover', ['in', 'geoid', '']);
				map.setFilter('places_filter', ['in', 'geoid', props.geoid]);  //reset in case 
				map.setFilter('counties_filter', ['in', 'geoid', '']); //reset in case
				map.setFilter('states_filter', ['in', 'geoid', '']);
				$('#loading-mask').show();
				setTimeout(() => {
					//console.log("updating filter from place click");
					updateFilter();
					$('#loading-mask').hide();
				},0);
			}	
		});
*/


        map.on('mousemove', 'pws', function (e) {
            if(map.getZoom()< 5)
                return;
			else if(map.getZoom()<8 && geoFilterId!=''){
	            map.getCanvas().style.cursor = 'pointer';            
				return;
			}

            if (mapHov) {
                mapHov.remove();
                mapHov = null;
            }

            map.getCanvas().style.cursor = 'pointer';            
            const pws = e.features[0].properties;
            map.setFilter('pws_hover', ['in', 'pwsid', pws.pwsid]);

			const pws_data = mergedData.features.find(feature => feature.properties.pwsid === pws.pwsid);

			let infoHTML = '<div class="map-detail-header"><p><strong>Utility Name:</strong> '+pws_data.properties.pws_name+'</p>';
			infoHTML += '<p><strong>System ID:</strong> '+pws_data.properties.pwsid+'<p></div>';
			infoHTML += '<div class="map-detail-body"><p><strong>Phone number: </strong>'+pws_data.properties.phone_number+'<p>';
			infoHTML += '<p><strong>Service type:</strong> '+pws_data.properties.owner_type+'<p>';
			infoHTML += '<p><strong>Service connections:</strong> '+pws_data.properties.service_connections_count.toLocaleString('en-US')+'<p>';
			infoHTML += '<p><strong>Customers served:</strong> '+pws_data.properties.total_pop.toLocaleString('en-US')+'<p>';
			infoHTML += '<p><strong>Years in operation:</strong> '+pws_data.properties.years_operating.toLocaleString('en-US')+'<p>';
			infoHTML += '<p><strong>Total violations:</strong> '+pws_data.properties.total_viols_10yr.toLocaleString('en-US')+' in the last 10 years<p>';
			/* append a line for each filter that is set */

			if(
				( //any are checked
					$('#water-source-ground').is(':checked') ||
					$('#water-source-surface').is(':checked') 
				) &&
				!( //not all are checked
					$('#water-source-ground').is(':checked') &&
					$('#water-source-surface').is(':checked') 
				)
			)
				infoHTML += '<p><span class="green-bar"></span><strong>Primary type:</strong> '+pws_data.properties.gw_sw_code+'<p>';

			if($('#has-source-water-protection').is(':checked'))
				infoHTML += '<p><span class="green-bar"></span><strong>Has source protection:</strong> '+pws_data.properties.source_water_protection_code+'<p>';

			if(
				( //any are checked
					$('#type-federal-government').is(':checked') ||
					$('#type-state-government').is(':checked') ||
					$('#type-local-government').is(':checked') ||
					$('#type-private').is(':checked') ||
					$('#type-public-private').is(':checked') ||
					$('#type-native-american').is(':checked') 
				) &&
				!( //not all are checked
					$('#type-federal-government').is(':checked') &&
					$('#type-state-government').is(':checked') &&
					$('#type-local-government').is(':checked') &&
					$('#type-private').is(':checked') &&
					$('#type-public-private').is(':checked') &&
					$('#type-native-american').is(':checked')
				)
			)
				infoHTML += '<p><span class="green-bar"></span><strong>Ownership:</strong> '+pws_data.properties.owner_type+'<p>';

			if(
				( //any are checked
					$('#primacy-type-state').is(':checked') ||
					$('#primacy-type-tribal').is(':checked') ||
					$('#primacy-type-territory').is(':checked')  
				) &&
				!( //not all are checked
					$('#primacy-type-state').is(':checked') &&
					$('#primacy-type-tribal').is(':checked') &&
					$('#primacy-type-territory').is(':checked') 
				)
			)
				infoHTML += '<p><span class="green-bar"></span><strong>Authority:</strong> '+pws_data.properties.primacy_type+'<p>';

			if($('#is-wholesaler').is(':checked'))
				infoHTML += '<p><span class="green-bar"></span><strong>Is wholesaler:</strong> '+pws_data.properties.is_wholesaler_ind+'<p>';

			if($('#is-school-or-daycare').is(':checked'))
				infoHTML += '<p><span class="green-bar"></span><strong>Is school or daycare:</strong> '+pws_data.properties.is_school_or_daycare_ind+'<p>';


			if(
				( //any are checked
					$('#type-system-sourced').is(':checked') ||
					$('#type-modeled').is(':checked') 
				) &&
				!( //not all are checked
					$('#type-system-sourced').is(':checked') &&
					$('#type-modeled').is(':checked') 
				)
			)			
				infoHTML += '<p><span class="green-bar"></span><strong>Boundary type:</strong> '+pws_data.properties.symbology_field+'<p>';
				
			if($('#area-min').val()*1 > 0 || $('#area-max').val()*1 < 999999)
				infoHTML += '<p><span class="green-bar"></span><strong>Area in square miles:</strong> '+pws_data.properties.epic_area_mi2.toLocaleString('en-US')+' square miles<p>';

			if($('#compliance-open-violations').is(':checked'))
				infoHTML += '<p><span class="green-bar"></span><strong>Open violations:</strong> '+pws_data.properties.open_health_viol.toLocaleString('en-US')+'<p>';

			if(
				$('#viols-groundwater-5yrs').is(':checked') ||
				$('#viols-surface-water-5yrs').is(':checked') ||
				$('#viols-lead-copper-5yrs').is(':checked') ||
				$('#viols-radionuclides-5yrs').is(':checked') ||
				$('#viols-inorganic-5yrs').is(':checked') ||
				$('#viols-synthetic-5yrs').is(':checked') ||
				$('#viols-vocs-5yrs').is(':checked') ||
				$('#viols-coliform-5yrs').is(':checked') ||
				$('#viols-stage-1-disinfectants-5yrs').is(':checked') ||
				$('#viols-stage-2-disinfectants-5yrs').is(':checked')
			)
				infoHTML += '<p><span class="green-bar"></span><strong>Health violations in the last 5 years</strong><p>';

			if($('#viols-groundwater-5yrs').is(':checked'))
				infoHTML += '<p style="margin-left: 4px;"><span class="green-bar"></span><strong>Ground water:</strong> '+pws_data.properties.groundwater_rule_healthbased_5yr.toLocaleString('en-US')+'<p>';
			if($('#viols-surface-water-5yrs').is(':checked'))
				infoHTML += '<p style="margin-left: 4px;"><span class="green-bar"></span><strong>Surface water treatment:</strong> '+pws_data.properties.surface_water_treatment_rules_healthbased_5yr.toLocaleString('en-US')+'<p>';
			if($('#viols-lead-copper-5yrs').is(':checked'))
				infoHTML += '<p style="margin-left: 4px;"><span class="green-bar"></span><strong>Lead &amp; copper:</strong> '+pws_data.properties.lead_and_copper_rule_healthbased_5yr.toLocaleString('en-US')+'<p>';		
			if($('#viols-radionuclides-5yrs').is(':checked'))
				infoHTML += '<p style="margin-left: 4px;"><span class="green-bar"></span><strong>Radionuclides:</strong> '+pws_data.properties.radionuclides_and_revised_rad_rule_healthbased_5yr.toLocaleString('en-US')+'<p>';
			if($('#viols-inorganic-5yrs').is(':checked'))
				infoHTML += '<p style="margin-left: 4px;"><span class="green-bar"></span><strong>Inorganic chemicals:</strong> '+pws_data.properties.inorganic_chemicals_healthbased_5yr.toLocaleString('en-US')+'<p>';			
			if($('#viols-synthetic-5yrs').is(':checked'))
				infoHTML += '<p style="margin-left: 4px;"><span class="green-bar"></span><strong>Synthetic organic chemicals:</strong> '+pws_data.properties.synthetic_organic_chemicals_healthbased_5yr.toLocaleString('en-US')+'<p>';		
			if($('#viols-vocs-5yrs').is(':checked'))
				infoHTML += '<p style="margin-left: 4px;"><span class="green-bar"></span><strong>Volatile organic chemicals:</strong> '+pws_data.properties.volatile_organic_chemicals_healthbased_5yr.toLocaleString('en-US')+'<p>';		
			if($('#viols-coliform-5yrs').is(':checked'))
				infoHTML += '<p style="margin-left: 4px;"><span class="green-bar"></span><strong>Coliform:</strong> '+pws_data.properties.total_coliform_rules_healthbased_5yr.toLocaleString('en-US')+'<p>';
			if($('#viols-stage-1-disinfectants-5yrs').is(':checked'))
				infoHTML += '<p style="margin-left: 4px;"><span class="green-bar"></span><strong>Stage 1 disinfectants:</strong> '+pws_data.properties.stage_1_disinfectants_and_byproducts_rule_healthbased_5yr.toLocaleString('en-US')+'<p>';	
			if($('#viols-stage-2-disinfectants-5yrs').is(':checked'))
				infoHTML += '<p style="margin-left: 4px;"><span class="green-bar"></span><strong>Stage 2 disinfectants:</strong> '+pws_data.properties.stage_2_disinfectants_and_byproducts_rule_healthbased_5yr.toLocaleString('en-US')+'<p>';		
			
			if(
				$('#viols-groundwater').is(':checked') ||
				$('#viols-surface-water').is(':checked') ||
				$('#viols-lead-copper').is(':checked') ||
				$('#viols-radionuclides').is(':checked') ||
				$('#viols-inorganic').is(':checked') ||
				$('#viols-synthetic').is(':checked') ||
				$('#viols-vocs').is(':checked') ||
				$('#viols-coliform').is(':checked') ||
				$('#viols-stage-1-disinfectants').is(':checked') ||
				$('#viols-stage-2-disinfectants').is(':checked')
			)
				infoHTML += '<p><span class="green-bar"></span><strong>Health violations in the last 10 years</strong><p>';

			if($('#viols-groundwater').is(':checked'))
				infoHTML += '<p style="margin-left: 4px;"><span class="green-bar"></span><strong>Ground water:</strong> '+pws_data.properties.groundwater_rule_healthbased_10yr.toLocaleString('en-US')+'<p>';
			if($('#viols-surface-water').is(':checked'))
				infoHTML += '<p style="margin-left: 4px;"><span class="green-bar"></span><strong>Surface water treatment:</strong> '+pws_data.properties.surface_water_treatment_rules_healthbased_10yr.toLocaleString('en-US')+'<p>';
			if($('#viols-lead-copper').is(':checked'))
				infoHTML += '<p style="margin-left: 4px;"><span class="green-bar"></span><strong>Lead &amp; copper:</strong> '+pws_data.properties.lead_and_copper_rule_healthbased_10yr.toLocaleString('en-US')+'<p>';		
			if($('#viols-radionuclides').is(':checked'))
				infoHTML += '<p style="margin-left: 4px;"><span class="green-bar"></span><strong>Radionuclides:</strong> '+pws_data.properties.radionuclides_and_revised_rad_rule_healthbased_10yr.toLocaleString('en-US')+'<p>';
			if($('#viols-inorganic').is(':checked'))
				infoHTML += '<p style="margin-left: 4px;"><span class="green-bar"></span><strong>Inorganic chemicals:</strong> '+pws_data.properties.inorganic_chemicals_healthbased_10yr.toLocaleString('en-US')+'<p>';			
			if($('#viols-synthetic').is(':checked'))
				infoHTML += '<p style="margin-left: 4px;"><span class="green-bar"></span><strong>Synthetic organic chemicals:</strong> '+pws_data.properties.synthetic_organic_chemicals_healthbased_10yr.toLocaleString('en-US')+'<p>';		
			if($('#viols-vocs').is(':checked'))
				infoHTML += '<p style="margin-left: 4px;"><span class="green-bar"></span><strong>Volatile organic chemicals:</strong> '+pws_data.properties.volatile_organic_chemicals_healthbased_10yr.toLocaleString('en-US')+'<p>';		
			if($('#viols-coliform').is(':checked'))
				infoHTML += '<p style="margin-left: 4px;"><span class="green-bar"></span><strong>Coliform:</strong> '+pws_data.properties.total_coliform_rules_healthbased_10yr.toLocaleString('en-US')+'<p>';
			if($('#viols-stage-1-disinfectants').is(':checked'))
				infoHTML += '<p style="margin-left: 4px;"><span class="green-bar"></span><strong>Stage 1 disinfectants:</strong> '+pws_data.properties.stage_1_disinfectants_and_byproducts_rule_healthbased_10yr.toLocaleString('en-US')+'<p>';	
			if($('#viols-stage-2-disinfectants').is(':checked'))
				infoHTML += '<p style="margin-left: 4px;"><span class="green-bar"></span><strong>Stage 2 disinfectants:</strong> '+pws_data.properties.stage_2_disinfectants_and_byproducts_rule_healthbased_10yr.toLocaleString('en-US')+'<p>';		

			if($('#viols-paperwork-5yrs').is(':checked'))
				infoHTML += '<p><span class="green-bar"></span><strong>Non-health violations in last 5 years:</strong> '+pws_data.properties.paperwork_viols_5yr.toLocaleString('en-US')+'<p>';
			if($('#viols-paperwork').is(':checked'))
				infoHTML += '<p><span class="green-bar"></span><strong>Non-health violations in last 10 years:</strong> '+pws_data.properties.paperwork_viols_10yr.toLocaleString('en-US')+'<p>';

			if($('#boil-water-notices').is(':checked') && pws_data.properties.total_bwn > 0)
				infoHTML += '<p><span class="green-bar"></span><strong>Boil water notices:</strong> '+pws_data.properties.total_bwn.toLocaleString('en-US')+'<p>';


			if(
				( //any are checked
					$('#pop-very-small').hasClass('active') ||
					$('#pop-small').hasClass('active') ||
					$('#pop-medium').hasClass('active') ||
					$('#pop-large').hasClass('active') ||
					$('#pop-very-large').hasClass('active') 
				) &&
				!( //not all are checked
					$('#pop-very-small').hasClass('active') &&
					$('#pop-small').hasClass('active') &&
					$('#pop-medium').hasClass('active') &&
					$('#pop-large').hasClass('active') &&
					$('#pop-very-large').hasClass('active') 
				)
			)
				infoHTML += '<p><span class="green-bar"></span><strong>Population:</strong> '+pws_data.properties.total_pop.toLocaleString('en-US')+'<p>';

			if($('#density-min').val()*1 > 0 || $('#density-max').val()*1 < 999999)
				infoHTML += '<p><span class="green-bar"></span><strong>Population Density:</strong> '+pws_data.properties.epic_pop_density.toLocaleString('en-US')+' per sqare mile<p>';

			if($('#pop-change').is(':checked'))
				infoHTML += '<p><span class="green-bar"></span><strong>Change in people in last 10 years:</strong> '+pws_data.properties.total_pop_pct_change_2011_2021.toLocaleString('en-US')+'%<p>';
			if($('#mhi-change').is(':checked'))
				infoHTML += '<p><span class="green-bar"></span><strong>Change in income in last 10 years:</strong> '+pws_data.properties.mhi_pct_change_2011_2021.toLocaleString('en-US')+'%<p>';
			
			if($('#poverty').is(':checked'))
				infoHTML += '<p><span class="green-bar"></span><strong>Households below poverty line:</strong> '+pws_data.properties.hh_below_pov_per.toLocaleString('en-US')+'%<p>';
			if($('#unemployment').is(':checked'))
				infoHTML += '<p><span class="green-bar"></span><strong>Unemployment:</strong> '+pws_data.properties.laborforce_unemployed_per.toLocaleString('en-US')+'%<p>';
			if($('#mhi').is(':checked'))
				infoHTML += '<p><span class="green-bar"></span><strong>Annual median household income:</strong> $'+pws_data.properties.mhi.toLocaleString('en-US')+'<p>';
			if($('#bachelors').is(':checked'))
				infoHTML += '<p><span class="green-bar"></span><strong>Higher education attainment:</strong> '+pws_data.properties.bachelors_per.toLocaleString('en-US')+'%<p>';
			if($('#under5').is(':checked'))
				infoHTML += '<p><span class="green-bar"></span><strong>Children under 5:</strong> '+pws_data.properties.ageunder_5_per.toLocaleString('en-US')+'%<p>';
			if($('#over61').is(':checked'))
				infoHTML += '<p><span class="green-bar"></span><strong>Elderly over 61:</strong> '+pws_data.properties.age_over_61_per.toLocaleString('en-US')+'%<p>';

			if($('#poc').is(':checked'))
				infoHTML += '<p><span class="green-bar"></span><strong>People of color:</strong> '+pws_data.properties.poc_alone_per.toLocaleString('en-US')+'%<p>';
			if($('#white').is(':checked'))
				infoHTML += '<p><span class="green-bar"></span><strong>White:</strong> '+pws_data.properties.white_alone_per.toLocaleString('en-US')+'%<p>';
			if($('#black').is(':checked'))
				infoHTML += '<p><span class="green-bar"></span><strong>Black:</strong> '+pws_data.properties.black_alone_per.toLocaleString('en-US')+'%<p>';
			if($('#aian').is(':checked'))
				infoHTML += '<p><span class="green-bar"></span><strong>American Indian and Alaskan Native:</strong> '+pws_data.properties.aian_alone_per.toLocaleString('en-US')+'%<p>';
			if($('#napi').is(':checked'))
				infoHTML += '<p><span class="green-bar"></span><strong>Native Hawaiian and Pacific Islanders:</strong> '+pws_data.properties.napi_alone_per.toLocaleString('en-US')+'%<p>';
			if($('#asian').is(':checked'))
				infoHTML += '<p><span class="green-bar"></span><strong>Asian:</strong> '+pws_data.properties.asian_alone_per.toLocaleString('en-US')+'%<p>';
			if($('#hisp').is(':checked'))
				infoHTML += '<p><span class="green-bar"></span><strong>Latino/a:</strong> '+pws_data.properties.hisp_alone_per.toLocaleString('en-US')+'%<p>';
			if($('#race-other').is(':checked'))
				infoHTML += '<p><span class="green-bar"></span><strong>Other:</strong> '+pws_data.properties.other_alone_per.toLocaleString('en-US')+'%<p>';
			if($('#race-mixed').is(':checked'))
				infoHTML += '<p><span class="green-bar"></span><strong>Mixed race:</strong> '+pws_data.properties.mixed_alone_per.toLocaleString('en-US')+'%<p>';

			if($('#disadvantaged').is(':checked'))
				infoHTML += '<p><span class="green-bar"></span><strong>Disadvantaged area:</strong> '+pws_data.properties.a_int_identified_as_disadvantaged.toLocaleString('en-US')+'%<p>';
			if($('#svi').is(':checked'))
				infoHTML += '<p><span class="green-bar"></span><strong>Social Vulnerability Index:</strong> '+pws_data.properties.pw_int_pop_rpl_themes.toLocaleString('en-US')+'%<p>';
			if($('#cvi').is(':checked'))
				infoHTML += '<p><span class="green-bar"></span><strong>Climate Vulnerability Index:</strong> '+pws_data.properties.a_int_overall_cvi_score.toLocaleString('en-US')+'%<p>';
			

			if($('#annual-water-sewer-bill').is(':checked'))
				infoHTML += '<p><span class="green-bar"></span><strong>Annual water and sewer bill:</strong> '+pws_data.properties.most_common_rate_tidy.toLocaleString('en-US')+'<p>';

			if($('#projs-funded').is(':checked'))
				infoHTML += '<p><span class="green-bar"></span><strong>Received state revolving fund financing:</strong> '+pws_data.properties.times_funded.toLocaleString('en-US')+'<p>';
			if($('#total-assistance').is(':checked'))
				infoHTML += '<p><span class="green-bar"></span><strong>Received state revolving fund assistance:</strong> $'+pws_data.properties.total_srf_assistance.toLocaleString('en-US')+'<p>';
			if($('#total-prin-forgive').is(':checked'))
				infoHTML += '<p><span class="green-bar"></span><strong>Benefited from state revolving fund principal forgiveness:</strong> $'+pws_data.properties.total_principal_forgiveness.toLocaleString('en-US')+'<p>';

			if($('#num-facilities').is(':checked'))
				infoHTML += '<p><span class="green-bar"></span><strong>Source water connections:</strong> '+pws_data.properties.num_facilities.toLocaleString('en-US')+'<p>';
			if($('#permit-violations').is(':checked'))
				infoHTML += '<p><span class="green-bar"></span><strong>Pollution permits with breaches:</strong> '+pws_data.properties.total_permit_eff_viols.toLocaleString('en-US')+'<p>';
			if($('#open-usts').is(':checked'))
				infoHTML += '<p><span class="green-bar"></span><strong>Underground storage tanks:</strong> '+pws_data.properties.total_open_usts.toLocaleString('en-US')+'<p>';
			if($('#rmps').is(':checked'))
				infoHTML += '<p><span class="green-bar"></span><strong>Risk management plan facilities:</strong> '+pws_data.properties.total_facilities_w_rmps.toLocaleString('en-US')+'<p>';
			if($('#streams').is(':checked'))
				infoHTML += '<p><span class="green-bar"></span><strong>Streams with impaired or threatened surface waters:</strong> '+pws_data.properties.streams_303d_list.toLocaleString('en-US')+'<p>';
			
			//infoHTML += '<p><span class="green-bar"></span><strong>Resource:</strong> <a target="_blank" href="'+pws_data.properties.detailed_facility_report+'">Enforcement and compliance history</a><p>';
			//infoHTML += '<p><span class="green-bar"></span><strong>Resource:</strong> <a target="_blank" href="'+pws_data.properties.ewg_report_link+'">Tap water database</a><p>';
			//infoHTML += '<p style="text-align:center;"><a href="#" class="btn-report">Create report</a><p>';
			infoHTML += '</div>';
			//infoHTML += '<div class="map-hover-footer"><p style="text-align:center;"><em>Click to create report</em><p></div>';
			
            mapHov = new mapboxgl.Popup({closeButton: false, className: "infoBub", maxWidth: "400px"})
                .setLngLat(e.lngLat)
                .setHTML(infoHTML)
                .addTo(map);			
        });

        map.on('mouseleave', 'pws', function () {
            if(map.getZoom()< 5)
                return;
			else if(map.getZoom()<8 && geoFilterId!=''){
	            map.getCanvas().style.cursor = 'grab';            
				return;
			}

			map.getCanvas().style.cursor = 'grab';
            if (mapHov) {
                mapHov.remove();
                mapHov = null;
            }
            map.setFilter('pws_hover', ['in', 'pwsid', '']);
        });

		map.on('zoomstart', function() { 
            if (mapHov) {
                mapHov.remove();
                mapHov = null;
            }
            map.setFilter('pws_hover', ['in', 'pwsid', '']);

		})

        map.on('click', 'pws', function (e) {
            if(map.getZoom()<5 || geoFilterId=='')
				return;
            if(map.getZoom()>=5 && map.getZoom() < 8 && geoFilterId!=''){
				map.flyTo({
					center: e.lngLat,
					zoom: 8.5					
				})
                return;
			}
			if(map.getZoom()<8)
				return;
			
			const pws = e.features[0].properties;
			//console.log(pws);


			// Clicking on PWS now displays a report modal
			
			//$("#filter-list-container").addClass("hidden");
			//$("#container-map").addClass("hidden");
			//$("#container-report").removeClass('hidden');
			//window.dispatchEvent(new Event('resize'));

        });

		//when data layers are fully loaded, populate pwsData
		map.once('idle',function(){ 

			//add listener to clear geographic filter
			$('.mapboxgl-ctrl-geocoder--icon-close').on('click', function(){
				map.setFilter('states_filter', ['in', 'geoid', '']);
				map.setFilter('counties_filter', ['in', 'geoid', '']);
				map.setFilter('places_filter', ['in', 'geoid', '']);
				pwsFilterGeo = [];
				map.flyTo({		
					center: [-97.6, 40.27], 
					zoom: 3.5 // starting zoom
				});
				$('#loading-mask').show();
				setTimeout(() => {
					//console.log("updating filter from clear geocoder");
					updateFilter();
					$('#loading-mask').hide();
				},0);		

			});

			features = map.querySourceFeatures('wdt', {sourceLayer: 'pws_sabs'});
            features = getUniqueFeatures(features,'pwsid');
            const pws_sabs = features;

            features = map.querySourceFeatures('wdt', {sourceLayer: 'pws_cejst'});
            features = getUniqueFeatures(features,'pwsid');
            const pws_cejst = features;

            features = map.querySourceFeatures('wdt', {sourceLayer: 'pws_ejscreen'});
            features = getUniqueFeatures(features,'pwsid');
            const pws_ejscreen = features;

            features = map.querySourceFeatures('wdt', {sourceLayer: 'pws_acs'});
            features = getUniqueFeatures(features,'pwsid');
            const pws_acs = features;

            features = map.querySourceFeatures('wdt', {sourceLayer: 'pws_cvi'});
            features = getUniqueFeatures(features,'pwsid');
            const pws_cvi = features;

            features = map.querySourceFeatures('wdt', {sourceLayer: 'pws_viols'});
            features = getUniqueFeatures(features,'pwsid');
            const pws_viols = features;

            features = map.querySourceFeatures('wdt', {sourceLayer: 'pws_svi'});
            features = getUniqueFeatures(features,'pwsid');
            const pws_svi = features;

            features = map.querySourceFeatures('wdt', {sourceLayer: 'pws_10yr'});
            features = getUniqueFeatures(features,'pwsid');
            const pws_10yr = features;

            features = map.querySourceFeatures('wdt', {sourceLayer: 'pws_funding'});
            features = getUniqueFeatures(features,'pwsid');
            const pws_funding = features;

			features = map.querySourceFeatures('wdt', {sourceLayer: 'pws_bwn'});
            features = uniqueByProperties(features);
            const pws_bwn = features;

            features = map.querySourceFeatures('wdt', {sourceLayer: 'pws_npdes'});
            features = uniqueByProperties(features);
            const pws_npdes = features;
		
            /*
			pwsData['pws_sabs']=pws_sabs;
			pwsData['pws_cejst']=pws_cejst;
			pwsData['pws_ejscreen']=pws_ejscreen;
			pwsData['pws_acs']=pws_acs;
			pwsData['pws_cvi']=pws_cvi;
			pwsData['pws_viols']=pws_viols;
			pwsData['pws_svi']=pws_svi;
			pwsData['pws_10yr']=pws_10yr;
			pwsData['pws_bwn']=pws_bwn;
			pwsData['pws_npdes']=pws_npdes;
			pwsData['pws_funding']=pws_funding;
			*/
			

			mergedData = mergeGeoJSONById({features: pws_sabs},{features: pws_cejst});
			mergedData = mergeGeoJSONById(mergedData, {features: pws_ejscreen});
			mergedData = mergeGeoJSONById(mergedData, {features: pws_acs});
			mergedData = mergeGeoJSONById(mergedData, {features: pws_cvi});
			mergedData = mergeGeoJSONById(mergedData, {features: pws_10yr});
			mergedData = mergeGeoJSONById(mergedData, {features: pws_bwn});
			mergedData = mergeGeoJSONById(mergedData, {features: pws_npdes});
			mergedData = mergeGeoJSONById(mergedData, {features: pws_funding});
			mergedData = mergeGeoJSONById(mergedData, {features: pws_svi});
			mergedData = mergeGeoJSONById(mergedData, {features: pws_viols});
						
			//map.flyTo({zoom:3.5, duration:6000});
			map.setZoom(3.5);
			$('#loading-mask').css('background', 'rgba(200, 200, 200, 0.5)')

			function sliderListeners(slider){
				$('#minSlider-'+slider).on('input', function(){
					sliderChange('min',slider);
				});
				$('#minSlider-'+slider).on('change', function(){
					$('#loading-mask').show();
					setTimeout(() => {
						setTimeout(() => {
							//console.log("updating filter from "+slider+" min change");
							updateFilter();
							$('#loading-mask').hide();
						},0);		
					},900);		
				});
				$('#maxSlider-'+slider).on('input', function(){
					sliderChange('max',slider);
				});
				$('#maxSlider-'+slider).on('change', function(){
					$('#loading-mask').show();
					setTimeout(() => {
						setTimeout(() => {
							//console.log("updating filter from "+slider+" max change");
							updateFilter();
							$('#loading-mask').hide();
						},0);		
					},900);		
				});
				$('#minInput-'+slider).on('change', function(){
					$('#loading-mask').show();
					setTimeout(() => {
						inputChange('min',slider);
						//console.log("updating filter from "+slider+" min input change");
					    updateFilter();
						$('#loading-mask').hide();
					},0);		
				});
				$('#maxInput-'+slider).on('change', function(){
					$('#loading-mask').show();
					setTimeout(() => {
						inputChange('max',slider);
						//console.log("updating filter from "+slider+" max input change");
					    updateFilter();
						$('#loading-mask').hide();
					},0);		
				});
				$('#'+slider).on('click', function(){
					if($(this).is(':checked')){
						sliderChange('min',slider);
						sliderChange('max',slider);
						if($(this).hasClass('viols-health-5yrs') && $('#viols-health-5yrs').is(':checked')){
							hideOptions(slider);
						}
						else if($(this).hasClass('viols-health') && $('#viols-health').is(':checked')){
							hideOptions(slider);
						}
						else if($(this).hasClass('watershed-hazards') && $('#watershed-hazards').is(':checked')){
							hideOptions(slider);
						} else {
							showOptions(slider);
						}
					} else {
						hideOptions(slider);
					}
				});
			}
			// Sliders

			//sliderListeners('area');
			//sliderDataXwalk['area'] = {prop: 'epic_area_mi2'}; 
			//sliderListeners('population-density');
			//sliderDataXwalk['population-density'] = {prop: 'epic_pop_density'};
			//sliderListeners('customers');
			//sliderDataXwalk['customers'] = {prop: 'total_pop'};


			sliderListeners('viols-lead-copper-5yrs');
			sliderDataXwalk['viols-lead-copper-5yrs'] = {prop: 'lead_and_copper_rule_healthbased_5yr'};	
			sliderListeners('viols-radionuclides-5yrs');
			sliderDataXwalk['viols-radionuclides-5yrs'] = {prop: 'radionuclides_and_revised_rad_rule_healthbased_5yr'};	
			sliderListeners('viols-groundwater-5yrs');
			sliderDataXwalk['viols-groundwater-5yrs'] = {prop: 'groundwater_rule_healthbased_5yr'};	
			sliderListeners('viols-surface-water-5yrs');
			sliderDataXwalk['viols-surface-water-5yrs'] = {prop: 'surface_water_treatment_rules_healthbased_5yr'};	
			sliderListeners('viols-coliform-5yrs');
			sliderDataXwalk['viols-coliform-5yrs'] = {prop: 'total_coliform_rules_healthbased_5yr'};	
			sliderListeners('viols-inorganic-5yrs');
			sliderDataXwalk['viols-inorganic-5yrs'] = {prop: 'inorganic_chemicals_healthbased_5yr'};	
			sliderListeners('viols-stage-1-disinfectants-5yrs');
			sliderDataXwalk['viols-stage-1-disinfectants-5yrs'] = {prop: 'stage_1_disinfectants_and_byproducts_rule_healthbased_5yr'};	
			sliderListeners('viols-stage-2-disinfectants-5yrs');
			sliderDataXwalk['viols-stage-2-disinfectants-5yrs'] = {prop: 'stage_2_disinfectants_and_byproducts_rule_healthbased_5yr'};	
			sliderListeners('viols-synthetic-5yrs');
			sliderDataXwalk['viols-synthetic-5yrs'] = {prop: 'synthetic_organic_chemicals_healthbased_5yr'};	
			sliderListeners('viols-vocs-5yrs');
			sliderDataXwalk['viols-vocs-5yrs'] = {prop: 'volatile_organic_chemicals_healthbased_5yr'};	
			//sliderListeners('viols-health-5yrs');
			//sliderDataXwalk['viols-health-5yrs'] = {prop: 'health_viols_5yr'};	
			sliderListeners('viols-paperwork-5yrs');
			sliderDataXwalk['viols-paperwork-5yrs'] = {prop: 'paperwork_viols_5yr'};	
//			sliderListeners('viols-total-5yrs');
//			sliderDataXwalk['viols-total-5yrs'] = {prop: 'total_viols_5yr'};	

			sliderListeners('viols-lead-copper');
			sliderDataXwalk['viols-lead-copper'] = {prop: 'lead_and_copper_rule_healthbased_10yr'};	
			sliderListeners('viols-radionuclides');
			sliderDataXwalk['viols-radionuclides'] = {prop: 'radionuclides_and_revised_rad_rule_healthbased_10yr'};	
			sliderListeners('viols-groundwater');
			sliderDataXwalk['viols-groundwater'] = {prop: 'groundwater_rule_healthbased_10yr'};	
			sliderListeners('viols-surface-water');
			sliderDataXwalk['viols-surface-water'] = {prop: 'surface_water_treatment_rules_healthbased_10yr'};	
			sliderListeners('viols-coliform');
			sliderDataXwalk['viols-coliform'] = {prop: 'total_coliform_rules_healthbased_10yr'};	
			sliderListeners('viols-inorganic');
			sliderDataXwalk['viols-inorganic'] = {prop: 'inorganic_chemicals_healthbased_10yr'};	
			sliderListeners('viols-stage-1-disinfectants');
			sliderDataXwalk['viols-stage-1-disinfectants'] = {prop: 'stage_1_disinfectants_and_byproducts_rule_healthbased_10yr'};	
			sliderListeners('viols-stage-2-disinfectants');
			sliderDataXwalk['viols-stage-2-disinfectants'] = {prop: 'stage_2_disinfectants_and_byproducts_rule_healthbased_10yr'};	
			sliderListeners('viols-synthetic');
			sliderDataXwalk['viols-synthetic'] = {prop: 'synthetic_organic_chemicals_healthbased_10yr'};	
			sliderListeners('viols-vocs');
			sliderDataXwalk['viols-vocs'] = {prop: 'volatile_organic_chemicals_healthbased_10yr'};	
			//sliderListeners('viols-health');
			//sliderDataXwalk['viols-health'] = {prop: 'health_viols_10yr'};	
			sliderListeners('viols-paperwork');
			sliderDataXwalk['viols-paperwork'] = {prop: 'paperwork_viols_10yr'};	
//			sliderListeners('viols-total');
//			sliderDataXwalk['viols-total'] = {prop: 'total_viols_10yr'};	
			
			sliderListeners('boil-water-notices');
			sliderDataXwalk['boil-water-notices'] = {prop: 'total_bwn'};		
			//sliderListeners('dwater');
			//sliderDataXwalk['dwater'] = {prop: 'a_int_dwater'};		
																									
			sliderListeners('poverty');
			sliderDataXwalk['poverty'] = {prop: 'hh_below_pov_per'};
			sliderListeners('mhi');
			sliderDataXwalk['mhi'] = {prop: 'mhi'};	
			sliderListeners('unemployment');
			sliderDataXwalk['unemployment'] = {prop: 'laborforce_unemployed_per'};	
			sliderListeners('under5');
			sliderDataXwalk['under5'] = {prop: 'ageunder_5_per'};	
			sliderListeners('over61');
			sliderDataXwalk['over61'] = {prop: 'age_over_61_per'};	
			sliderListeners('bachelors');
			sliderDataXwalk['bachelors'] = {prop: 'bachelors_per'};	
			sliderListeners('poc');
			sliderDataXwalk['poc'] = {prop: 'poc_alone_per'};	
			sliderListeners('white');
			sliderDataXwalk['white'] = {prop: 'white_alone_per'};	
			sliderListeners('black');
			sliderDataXwalk['black'] = {prop: 'black_alone_per'};	
			sliderListeners('aian');
			sliderDataXwalk['aian'] = {prop: 'aian_alone_per'};	
			sliderListeners('napi');
			sliderDataXwalk['napi'] = {prop: 'napi_alone_per'};	
			sliderListeners('asian');
			sliderDataXwalk['asian'] = {prop: 'asian_alone_per'};	
			sliderListeners('hisp');
			sliderDataXwalk['hisp'] = {prop: 'hisp_alone_per'};	
			sliderListeners('race-other');
			sliderDataXwalk['race-other'] = {prop: 'other_alone_per'};	
			sliderListeners('race-mixed');
			sliderDataXwalk['race-mixed'] = {prop: 'mixed_alone_per'};	
			sliderListeners('pop-change');
			sliderDataXwalk['pop-change'] = {prop: 'total_pop_pct_change_2011_2021_cap'};	
			sliderListeners('mhi-change');
			sliderDataXwalk['mhi-change'] = {prop: 'mhi_pct_change_2011_2021_cap'};		

			sliderListeners('disadvantaged');
			sliderDataXwalk['disadvantaged'] = {prop: 'a_int_identified_as_disadvantaged'};	
			sliderListeners('svi');
			sliderDataXwalk['svi'] = {prop: 'pw_int_pop_rpl_themes'};
			sliderListeners('cvi');
			sliderDataXwalk['cvi'] = {prop: 'a_int_overall_cvi_score'};
																							
			sliderListeners('projs-invited');
			sliderDataXwalk['projs-invited'] = {prop: 'projects_invited_to_apply_over_fy_range'};
			sliderListeners('projs-funded');
			sliderDataXwalk['projs-funded'] = {prop: 'times_funded'};	
			sliderListeners('total-assistance');
			sliderDataXwalk['total-assistance'] = {prop: 'total_srf_assistance'};	
			sliderListeners('total-prin-forgive');
			sliderDataXwalk['total-prin-forgive'] = {prop: 'total_principal_forgiveness'};	
																									
			sliderListeners('num-facilities');
			sliderDataXwalk['num-facilities'] = {prop: 'num_facilities'};
			sliderListeners('permit-violations');
			sliderDataXwalk['permit-violations'] = {prop: 'total_permit_eff_viols'};	
			sliderListeners('open-usts');
			sliderDataXwalk['open-usts'] = {prop: 'total_open_usts'};	
			sliderListeners('rmps');
			sliderDataXwalk['rmps'] = {prop: 'total_facilities_w_rmps'};	
			sliderListeners('streams');
			sliderDataXwalk['streams'] = {prop: 'streams_303d_list'};	
																												
			$('#loading-mask').hide();

		})

  });

});

const mapColors = [
"#eff6fb",
"#d9e8f6",
"#aacdec",
"#73b3e7",
"#4f97d1",
"#2378c3",
"#2c608a",
"#1f303e",
"#11181d"
];

function updateMap(v){
	let data = mergedData.features;
	const prop = sliderDataXwalk[v].prop;
	//console.log(data.length);
	if(pwsFilterGeo.length>0){
		data = data.filter(feature => 
			pwsFilterGeo.includes(feature.properties.pwsid)
		);
	}
	//console.log(data.length);
	const propValues = data.map(feature => feature.properties[prop]).filter(value => value !== null && value !== undefined);
	const breaks = getQuantileBreaks(propValues,8);
	let fillExpr = ["case"];
	let colorScale = '<div class="key-color key-color-min">'+Math.min(...propValues)+'</div>';
	//breaks.forEach((b,i)=>{
	for(var i=0; i<breaks.length; i++){
		const b = breaks[i];
		const thisList = data.map(feature => {
			if(feature.properties[prop] !== null && feature.properties[prop] !== undefined){
				if(i===0 && feature.properties[prop] <= b){
					return feature.properties.pwsid;
				} else if(i>0 && feature.properties[prop] > breaks[i-1] && feature.properties[prop] <= b){
					return feature.properties.pwsid;
				}
			}
		}).filter(id => id !== undefined);
		fillExpr.push(["in", ["get","pwsid"],["literal",thisList]]);
		fillExpr.push(mapColors[i]);
		let colorScaleStyle = '';
		if(i===0)
			colorScaleStyle = ' key-color-first';
		else if(i===breaks.length-1)
			colorScaleStyle = ' key-color-last';
		colorScale += '<div title="'+b+'" class="key-color'+colorScaleStyle+'" style="background-color:'+mapColors[i]+';"></div>';
	}
	fillExpr.push("#ccc"); //default color
	//console.log(fillExpr);
	colorScale += '<div class="key-color key-color-max">'+Math.max(...propValues)+'</div>';
	$('#color-bar-'+v).html(colorScale);
	map.setPaintProperty("pws", "fill-color", fillExpr);

}

/* Globals */
let pwsFilterGeo = []; //state, county, place
let geoFilterName = '';
let geoFilterId = '';
let geoFilterType = '';
let sliderDataXwalk = {};
let filterGroupCounts = {'geo':0
						,'source':0
						,'attributes':0
						,'boundaries':0
						,'compliance':0
						,'population':0
						,'financial':0
						,'funding':0
						,'environmental':0};

function updateFilter(){
	
	//let now = new Date();
	//console.log('start filter:', now.toString());

	$('#filter-list-container').hide();
	
	map.setFilter('pws', null);
	map.setFilter('pws_outline', null);

	let filterArrays = [];

	//reset filter group counts
	filterGroupCounts = {'geo':0
						,'source':0
						,'attributes':0
						,'boundaries':0
						,'compliance':0
						,'population':0
						,'financial':0
						,'funding':0
						,'environmental':0};


	if(pwsFilterGeo.length>0){ //set by map search
		filterArrays.push(pwsFilterGeo);
		filterGroupCounts['geo']++;
	}
	//console.log('filterArrays',filterArrays);

	/* water source filter: 
		- an OR filter on pws_viols.primary_source_code
		- if all are checked or all are unchecked, no filter
		- any combination of checked/unchecked, set filter
	*/
	if(
		( //any are checked
			$('#water-source-ground').is(':checked') ||
			$('#water-source-surface').is(':checked') 
		) &&
		!( //not all are checked
			$('#water-source-ground').is(':checked') &&
			$('#water-source-surface').is(':checked') 
		)
	){
		let thisFilter = [];
		let vals = [];
		if($('#water-source-ground').is(':checked')){
			vals.push('Groundwater');
		}
		if($('#water-source-surface').is(':checked')){
			vals.push('Surface Water');
		}
		
		filterGroupCounts['source'] += vals.length;

		thisFilter = checkBoxFilter('gw_sw_code', vals);

		filterArrays.push(thisFilter);

	}
	//console.log('filterArrays',filterArrays);

	/* type owner filter: 
		- an OR filter on pws_viols.owner_name
		- if all are checked or all are unchecked, no filter
		- any combination of checked/unchecked, set filter
	*/
	if(
		( //any are checked
			$('#type-federal-government').is(':checked') ||
			$('#type-state-government').is(':checked') ||
			$('#type-local-government').is(':checked') ||
			$('#type-private').is(':checked') ||
			$('#type-public-private').is(':checked') ||
			$('#type-native-american').is(':checked') 
		) &&
		!( //not all are checked
			$('#type-federal-government').is(':checked') &&
			$('#type-state-government').is(':checked') &&
			$('#type-local-government').is(':checked') &&
			$('#type-private').is(':checked') &&
			$('#type-public-private').is(':checked') &&
			$('#type-native-american').is(':checked')
		)
	){

		let thisFilter = [];
		let vals = [];
		if($('#type-federal-government').is(':checked')){
			vals.push('Federal');
		}
		if($('#type-state-government').is(':checked')){
			vals.push('State');
		}
		if($('#type-local-government').is(':checked')){
			vals.push('Local');
		}
		if($('#type-private').is(':checked')){
			vals.push('Private');
		}
		if($('#type-public-private').is(':checked')){
			vals.push('Public/Private');
		}
		if($('#type-native-american').is(':checked')){
			vals.push('Native American');
		}

		filterGroupCounts['attributes'] += vals.length;

		thisFilter = checkBoxFilter('owner_type', vals);

		filterArrays.push(thisFilter);
	
	}

	/*  primacy filter: 
		- an OR filter on pws_viols.primacy_type
		- if all are checked or all are unchecked, no filter
		- any combination of checked/unchecked, set filter
	*/
	if(
		( //any are checked
			$('#primacy-type-state').is(':checked') ||
			$('#primacy-type-tribal').is(':checked') ||
			$('#primacy-type-territory').is(':checked')  
		) &&
		!( //not all are checked
			$('#primacy-type-state').is(':checked') &&
			$('#primacy-type-tribal').is(':checked') &&
			$('#primacy-type-territory').is(':checked') 
		)
	){
		let thisFilter = [];
		let vals = [];
		if($('#primacy-type-state').is(':checked')){
			vals.push('State');
		}
		if($('#primacy-type-tribal').is(':checked')){
			vals.push('Tribal');
		}
		if($('#primacy-type-territory').is(':checked')){
			vals.push('Territory');
		}

		filterGroupCounts['attributes'] += vals.length;

		thisFilter = checkBoxFilter('primacy_type', vals);

		filterArrays.push(thisFilter);

	}	
	//console.log('filterArrays',filterArrays);


	/* open violations filter: 
		- simple boolean filter on pws_viols.open_health_viol
	*/
	if($('#compliance-open-violations').is(':checked')){
		let thisFilter = [];
		let vals = [];

		vals.push('Yes');

		filterGroupCounts['compliance'] += vals.length;

		thisFilter = checkBoxFilter('open_health_viol', vals);

		filterArrays.push(thisFilter);
	}
	
	/* wholesaler filter: 
		- simple boolean filter on pws_viols.is_wholesaler_ind
	*/
	if($('#is-wholesaler').is(':checked')){

		let thisFilter = [];
		let vals = [];

		vals.push('Yes');

		filterGroupCounts['attributes'] += vals.length;

		thisFilter = checkBoxFilter('is_wholesaler_ind', vals);

		filterArrays.push(thisFilter);

	}

	/* school or daycare filter: 
		- simple boolean filter on pws_viols.is_school_or_daycare_ind
	*/
	if($('#is-school-or-daycare').is(':checked')){

		let thisFilter = [];
		let vals = [];

		vals.push('Yes');

		filterGroupCounts['attributes'] += vals.length;

		thisFilter = checkBoxFilter('is_school_or_daycare_ind', vals);

		filterArrays.push(thisFilter);

	}

	/* water source protection filter: 
		- simple boolean filter on pws_viols.source_water_protection_code
	*/
	if($('#has-source-water-protection').is(':checked')){
		let thisFilter = [];
		let vals = [];

		vals.push('Yes');

		filterGroupCounts['source'] += vals.length;

		thisFilter = checkBoxFilter('source_water_protection_code', vals);

		filterArrays.push(thisFilter);

	}

	/* boundary source filter: 
		- an OR filter on pws_sabs.symbology_field
		- if all are checked or all are unchecked, no filter
		- any combination of checked/unchecked, set filter
	*/
	if(
		( //any are checked
			$('#type-system-sourced').is(':checked') ||
			$('#type-modeled').is(':checked') 
		) &&
		!( //not all are checked
			$('#type-system-sourced').is(':checked') &&
			$('#type-modeled').is(':checked') 
		)
	){
		let thisFilter = [];
		let vals = [];
		if($('#type-system-sourced').is(':checked')){
			vals.push('System Sourced');
		}
		if($('#type-modeled').is(':checked')){
			vals.push('Modeled');
		}

		filterGroupCounts['boundaries'] += vals.length;

		thisFilter = checkBoxFilter('symbology_field', vals);

		filterArrays.push(thisFilter);

	}

	if($('#annual-water-sewer-bill').is(':checked') &&  //this is the parent checkbox that must be checked
		( //any are checked
			$('#annual-water-sewer-bill-lt125').is(':checked') ||
			$('#annual-water-sewer-bill-125-249').is(':checked') ||
			$('#annual-water-sewer-bill-250-499').is(':checked') ||
			$('#annual-water-sewer-bill-500-749').is(':checked') ||
			$('#annual-water-sewer-bill-750-999').is(':checked') ||
			$('#annual-water-sewer-bill-gt1000').is(':checked') ||
			$('#annual-water-sewer-bill-no-info').is(':checked')
		) &&
		!( //not all are checked
			$('#annual-water-sewer-bill-lt125').is(':checked') &&
			$('#annual-water-sewer-bill-125-249').is(':checked') &&
			$('#annual-water-sewer-bill-250-499').is(':checked') &&
			$('#annual-water-sewer-bill-500-749').is(':checked') &&
			$('#annual-water-sewer-bill-750-999').is(':checked') &&
			$('#annual-water-sewer-bill-gt1000').is(':checked') &&
			$('#annual-water-sewer-bill-no-info').is(':checked')
		)
	){
		let thisFilter = [];
		let vals = [];
		if($('#annual-water-sewer-bill-lt125').is(':checked')){
			vals.push('Most people pay < $125 for water & sewer annually');
		}		
		if($('#annual-water-sewer-bill-125-249').is(':checked')){
			vals.push('Most people pay between $125-249 for water & sewer annually');
		}
		if($('#annual-water-sewer-bill-250-499').is(':checked')){
			vals.push('Most people pay between $250-499 for water & sewer annually');
		}
		if($('#annual-water-sewer-bill-500-749').is(':checked')){
			vals.push('Most people pay between $500-749 for water & sewer annually');
		}
		if($('#annual-water-sewer-bill-750-999').is(':checked')){
			vals.push('Most people pay between $750-999 for water & sewer annually');
		}
		if($('#annual-water-sewer-bill-gt1000').is(':checked')){
			vals.push('Most people pay > $1000 for water & sewer annually');
		}
		if($('#annual-water-sewer-bill-no-info').is(':checked')){
			vals.push('No Information on annual water & sewer rates');
		}

		if(vals.length>0){
			filterGroupCounts['financial'] ++; //+= vals.length;
		}
		thisFilter = checkBoxFilter('most_common_rate_tidy', vals);

		filterArrays.push(thisFilter);

	}
	//console.log('filterArrays',filterArrays);


	/* Customers bin buttons:
		- an OR filter on pws_acs.total_pop
		- if all are active or all are not active, no filter
		- any combination of active/not active, set filter
	*/

	if(
		( //any are checked
			$('#pop-very-small').hasClass('active') ||
			$('#pop-small').hasClass('active') ||
			$('#pop-medium').hasClass('active') ||
			$('#pop-large').hasClass('active') ||
			$('#pop-very-large').hasClass('active') 
		) &&
		!( //not all are checked
			$('#pop-very-small').hasClass('active') &&
			$('#pop-small').hasClass('active') &&
			$('#pop-medium').hasClass('active') &&
			$('#pop-large').hasClass('active') &&
			$('#pop-very-large').hasClass('active') 
		)
	){
		let thisFilter = [];
		let vals = [];
		if($('#pop-very-small').hasClass('active')){
			vals.push([0,500]);
		}
		if($('#pop-small').hasClass('active')){
			vals.push([501,3300]);
		}
		if($('#pop-medium').hasClass('active')){
			vals.push([3301,10000]);
		}
		if($('#pop-large').hasClass('active')){
			vals.push([10001,100000]);
		}
		if($('#pop-very-large').hasClass('active')){
			vals.push([100001,999999999]);
		}


		filterGroupCounts['population'] += vals.length;

		for(const val of vals){
			thisFilter.push(...rangeFilter('total_pop', val[0], val[1]));
		}

		filterArrays.push(thisFilter);

	}

	/* Area min max select boxes:
		- filter on pws_sabs.epic_area_mi2
		- if min > 0 or max < 999999
	*/

	if($('#area-min').val()*1 > 0 || $('#area-max').val()*1 < 999999){
		let thisFilter = [];
		let lowVal = $('#area-min').val()*1;
		let highVal = $('#area-max').val()*1;
		thisFilter = rangeFilter('epic_area_mi2', lowVal, highVal);

		filterGroupCounts['boundaries'] ++;

		filterArrays.push(thisFilter);
	}

	/* Population density min max select boxes:
		- filter on pws_acs.epic_pop_density
		- if min > 0 or max < 999999
	*/

	if($('#density-min').val()*1 > 0 || $('#density-max').val()*1 < 999999){
		let thisFilter = [];
		let lowVal = $('#density-min').val()*1;
		let highVal = $('#density-max').val()*1;
		thisFilter = rangeFilter('epic_pop_density', lowVal, highVal);

		filterGroupCounts['population'] ++;

		filterArrays.push(thisFilter);
	}

	now = new Date();
	//console.log('start slider filters:', now.toString());


	/* watershed haxards filter: 
		- an OR filter on multiple watershed hazard sliders
		- if all are unchecked, no filter
	*/
	if(
		//$('#watershed-hazards').is(':checked')
		//&& ( //any are checked
			$('#num-facilities').is(':checked') ||
			$('#permit-violations').is(':checked') ||
			$('#open-usts').is(':checked') ||
			$('#rmps').is(':checked') ||
			$('#streams').is(':checked') 
		//)
	){
		let theseSliders = ['num-facilities','permit-violations','open-usts','rmps','streams'];
		let theseFilters = [];
		let data = mergedData.features;
	    if(pwsFilterGeo.length>0) //apply geography filter if set
	        data = data.filter(f => pwsFilterGeo.includes(f.properties.pwsid));

		//(features, key, min, max)
		let sliderFilter = data.reduce((ids, feature) => {
			const pwsid = feature.properties['pwsid'];
			for (const slider of theseSliders) {
				if($('#'+slider).is(':checked')){
					let min = $('#minInput-'+slider).val().replaceAll(',','')*1;
					let max = $('#maxInput-'+slider).val().replaceAll(',','')*1;
					const value = feature.properties[sliderDataXwalk[slider].prop];

					//when range controls are not displayed, the filter is defaulted to min=1 and max=999999999
					if(min==0) min = 1;
					if($("#container-filter-" + slider).hasClass('hidden')) max = 999999999;
					//console.log(slider,min,max);

					if (typeof value === "number" && value >= min && value <= max) {
						ids.push(pwsid);
					}
				}
			}

			return ids;
		}, []);

		thisFilter = sliderFilter;

		filterGroupCounts['environmental'] ++;
		filterArrays.push(thisFilter);
	}
	

	/* health violations filter: 
		- an OR filter on health violations sliders
		- if all are unchecked, no filter
	*/
	if(
		//$('#viols-health').is(':checked')  //no longer required
		//&& ( //any are checked
			$('#viols-lead-copper').is(':checked') ||
			$('#viols-radionuclides').is(':checked') ||
			$('#viols-groundwater').is(':checked') ||
			$('#viols-surface-water').is(':checked') ||
			$('#viols-coliform').is(':checked') ||
			$('#viols-inorganic').is(':checked') ||
			$('#viols-stage-1-disinfectants').is(':checked') ||
			$('#viols-stage-2-disinfectants').is(':checked') ||
			$('#viols-synthetic').is(':checked') ||
			$('#viols-vocs').is(':checked')
		//)
	){
		let theseSliders = ['viols-lead-copper','viols-radionuclides','viols-groundwater','viols-surface-water','viols-coliform','viols-inorganic','viols-stage-1-disinfectants','viols-stage-2-disinfectants','viols-synthetic','viols-vocs'];
		let theseFilters = [];
		let data = mergedData.features;
	    if(pwsFilterGeo.length>0) //apply geography filter if set
	        data = data.filter(f => pwsFilterGeo.includes(f.properties.pwsid));

		//(features, key, min, max)
		let sliderFilter = data.reduce((ids, feature) => {
			const pwsid = feature.properties['pwsid'];
			for (const slider of theseSliders) {
				if($('#'+slider).is(':checked')){
					let min = $('#minInput-'+slider).val().replaceAll(',','')*1;
					let max = $('#maxInput-'+slider).val().replaceAll(',','')*1;
					const value = feature.properties[sliderDataXwalk[slider].prop];

					//when range controls are not displayed, the filter is defaulted to min=1 and max=999999999
					if(min==0) min = 1;
					if($("#container-filter-" + slider).hasClass('hidden')) max = 999999999;
					//console.log(slider,min,max);

					if (typeof value === "number" && value >= min && value <= max) {
						ids.push(pwsid);
					}
				}
			}

			return ids;
		}, []);

		thisFilter = sliderFilter;
		//console.log(thisFilter);

		filterGroupCounts['compliance'] ++;
		filterArrays.push(thisFilter);
	}

	/* health violations filter: 
		- an OR filter on health violations sliders
		- if all are unchecked, no filter
	*/
	if(
		//$('#viols-health-5yrs').is(':checked')  //no longer required
		//&& ( //any are checked
			$('#viols-lead-copper-5yrs').is(':checked') ||
			$('#viols-radionuclides-5yrs').is(':checked') ||
			$('#viols-groundwater-5yrs').is(':checked') ||
			$('#viols-surface-water-5yrs').is(':checked') ||
			$('#viols-coliform-5yrs').is(':checked') ||
			$('#viols-inorganic-5yrs').is(':checked') ||
			$('#viols-stage-1-disinfectants-5yrs').is(':checked') ||
			$('#viols-stage-2-disinfectants-5yrs').is(':checked') ||
			$('#viols-synthetic-5yrs').is(':checked') ||
			$('#viols-vocs-5yrs').is(':checked')
		//)
	){
		let theseSliders = ['viols-lead-copper-5yrs','viols-radionuclides-5yrs','viols-groundwater-5yrs','viols-surface-water-5yrs','viols-coliform-5yrs','viols-inorganic-5yrs','viols-stage-1-disinfectants-5yrs','viols-stage-2-disinfectants-5yrs','viols-synthetic-5yrs','viols-vocs-5yrs'];
		let theseFilters = [];
		let data = mergedData.features;
	    if(pwsFilterGeo.length>0) //apply geography filter if set
	        data = data.filter(f => pwsFilterGeo.includes(f.properties.pwsid));

		//(features, key, min, max)
		let sliderFilter = data.reduce((ids, feature) => {
			const pwsid = feature.properties['pwsid'];
			for (const slider of theseSliders) {
				if($('#'+slider).is(':checked')){
					let min = $('#minInput-'+slider).val().replaceAll(',','')*1;
					let max = $('#maxInput-'+slider).val().replaceAll(',','')*1;
					const value = feature.properties[sliderDataXwalk[slider].prop];

					//when range controls are not displayed, the filter is defaulted to min=1 and max=999999999
					if(min==0) min = 1;
					if($("#container-filter-" + slider).hasClass('hidden')) max = 999999999;
					//console.log(slider,min,max);

					if (typeof value === "number" && value >= min && value <= max) {
						ids.push(pwsid);
					}
				}
			}

			return ids;
		}, []);

		thisFilter = sliderFilter;
		//console.log(thisFilter);

		filterGroupCounts['compliance'] ++;
		filterArrays.push(thisFilter);
	}

	//slider filters:

	for (const slider in sliderDataXwalk) {
		if (sliderDataXwalk.hasOwnProperty(slider)) {
			//console.log(slider);
			//exclude all the filters that are OR filters
			if(! [
					'viols-lead-copper','viols-radionuclides','viols-groundwater','viols-surface-water','viols-coliform','viols-inorganic','viols-stage-1-disinfectants','viols-stage-2-disinfectants','viols-synthetic','viols-vocs','viols-health','viols-total',
					'viols-lead-copper-5yrs','viols-radionuclides-5yrs','viols-groundwater-5yrs','viols-surface-water-5yrs','viols-coliform-5yrs','viols-inorganic-5yrs','viols-stage-1-disinfectants-5yrs','viols-stage-2-disinfectants-5yrs','viols-synthetic-5yrs','viols-vocs-5yrs','viols-health-5yrs','viols-total-5yrs',
					'num-facilities','permit-violations','open-usts','rmps','streams'
				].includes(slider))			
			{
				//console.log('checking slider:',slider);
				if(
					$('#'+slider).is(':checked') &&
					($('#minInput-'+slider).val().replaceAll(',','')*1 > $('#minInput-'+slider).prop('min')*1
					 || $('#maxInput-'+slider).val().replaceAll(',','')*1 < $('#maxInput-'+slider).prop('max')*1)
					//($('#minInput-'+slider).val().replaceAll(',','')*1 > 0 || $('#maxInput-'+slider).val().replaceAll(',','')*1 < $('#maxInput-'+slider).prop('max')*1)
				){
					
					let thisFilter = [];
					let lowVal = $('#minInput-'+slider).val().replaceAll(',','')*1;
					let highVal = $('#maxInput-'+slider).val().replaceAll(',','')*1;

					thisFilter = rangeFilter(sliderDataXwalk[slider].prop, lowVal, highVal);
			
					if(['projs-invited','projs-funded','total-assistance','total-prin-forgive'].includes(slider))
						filterGroupCounts['funding'] ++;
					else if(['boil-water-notices','viols-paperwork','viols-paperwork-5yrs'].includes(slider))
						filterGroupCounts['compliance'] ++;
					else //population
						filterGroupCounts['population'] ++;

					filterArrays.push(thisFilter);
				}	
			}			
		}
	}
	
	now = new Date();
	//console.log('finished all filters:', now.toString());

	//if(filterArrays.length==0){
	//	$('.container-filter-count').hide();
	//	return;
	//}

	//set count indicators
	$('.filter-count-group-1').parent().hide();
	$('.filter-count-group-2').parent().hide();
	$('.filter-count-group-3').parent().hide();
	$('.filter-count-group-4').parent().hide();
	$('.filter-count-group-5').parent().hide();
	$('.filter-count-group-10').parent().hide();
	if(filterGroupCounts.source>0){
		$('.filter-count-group-1').html(filterGroupCounts.source).parent().show();
		$("#container-menu-btn-1").addClass("has-filter");
	} else{
		$("#container-menu-btn-1").removeClass("has-filter");
	}
	if(filterGroupCounts.attributes>0){
		$('.filter-count-group-2').html(filterGroupCounts.attributes).parent().show();
		$("#container-menu-btn-2").addClass("has-filter");
	} else{
		$("#container-menu-btn-2").removeClass("has-filter");
	}
	if(filterGroupCounts.boundaries>0){
		$('.filter-count-group-3').html(filterGroupCounts.boundaries).parent().show();
		$("#container-menu-btn-3").addClass("has-filter");
	} else{
		$("#container-menu-btn-3").removeClass("has-filter");
	}
	if(filterGroupCounts.compliance>0) {
		$('.filter-count-group-4').html(filterGroupCounts.compliance).parent().show();
		$("#container-menu-btn-4").addClass("has-filter");
	} else{
		$("#container-menu-btn-4").removeClass("has-filter");
	}
	if(filterGroupCounts.population>0) {
		$('.filter-count-group-5').html(filterGroupCounts.population).parent().show();
		$("#container-menu-btn-5").addClass("has-filter");
	} else{
		$("#container-menu-btn-5").removeClass("has-filter");
	}
	updateMoreFilterCount();
	
	//hide all for now
	$('.filter-count-group-1').parent().hide();
	$('.filter-count-group-2').parent().hide();
	$('.filter-count-group-3').parent().hide();
	$('.filter-count-group-4').parent().hide();
	$('.filter-count-group-5').parent().hide();
	$('.filter-count-group-10').parent().hide();

	//console.log(filterGroupCounts);
	//console.log(filterArrays);

	combinedFilter = [];
	if(filterArrays.length==1)
		combinedFilter = filterArrays[0];
	else if(filterArrays.length>1)
		combinedFilter = intersectArrays(filterArrays);

	//calculate summary stats and build table
	let totalViolations = 0;
	let totalAMI = 0;
	let totalPop = 0;

	mergedData.features.forEach(feature => {
		if(combinedFilter.length==0 || combinedFilter.includes(feature.properties['pwsid'])){
			if(feature.properties['open_health_viol'] == 'Yes'){
				totalViolations ++;
			}

			if(feature.properties['mhi'] === undefined || feature.properties['total_pop'] === undefined
				|| isNaN(feature.properties['mhi']) || isNaN(feature.properties['total_pop'])
				|| feature.properties['mhi'] === null || feature.properties['total_pop'] === null
				|| feature.properties['mhi'] <= 0 || feature.properties['total_pop'] <= 0)
			{
				return; //skip this feature
			}
			totalAMI += feature.properties['mhi']*feature.properties['total_pop'];
			totalPop += feature.properties['total_pop'];
		}
	});
	let avgAMI = Math.round(totalAMI/totalPop);

	$('.sumstat').html('');
	if(pwsFilterGeo.length>0){ //set by map search
		$('.stat-count-total').html(pwsFilterGeo.length.toLocaleString('en-US'));
		//$('.geo-filter').html('in '+$('.mapboxgl-ctrl-geocoder--input').val().replace(', United States',''));
		$('.geo-filter').html('in '+geoFilterName);
	} else { //all pws in the US
		$('.stat-count-total').html(mergedData.features.length.toLocaleString('en-US'));
	}
	//$('.stat-count').html(combinedFilter.length==0 ? $('.stat-count-total').html() : combinedFilter.length.toLocaleString('en-US'));
	$('.stat-count').html(filterArrays.length==0 ? $('.stat-count-total').html() : combinedFilter.length.toLocaleString('en-US'));
	$('.stat-open-viols').html(totalViolations.toLocaleString('en-US'));
	$('.stat-ami').html(avgAMI.toLocaleString('en-US'));
	$('.stat-served').html(totalPop.toLocaleString('en-US'));
	$('.sabs-stats').show();
	$('.intro-content').hide();
	$('.map-content-wrapper').removeClass("map-content-intro");
	$('.map-content-wrapper').addClass("map-content-stats");

	//clear out tbody
	$("#data-table tbody").empty();

	//console.log('About to filter map with',combinedFilter.length,'PWS');
	$('#loading-mask').show();
	if(combinedFilter.length>0 || pwsFilterGeo.length>0){
		map.setFilter('pws', ['in', 'pwsid'].concat(combinedFilter));
		map.setFilter('pws_outline', ['in', 'pwsid'].concat(combinedFilter));

		map.once('idle', () => {
			//console.log('Map filter applied');
			$('#loading-mask').hide();
		});
	}

	if($('#data-table').is(':visible')){
		populateTable();
	}
} //end updateFilter()

const sortFeaturesByProperty = (property, order = 'asc') => {
  const sortOrder = order === 'asc' ? 1 : -1;
  return function (a, b) {
    // Access the property within the 'properties' object
    const valA = a.properties[property];
    const valB = b.properties[property];

    let result = 0;
    if (valA < valB) {
      result = -1;
    } else if (valA > valB) {
      result = 1;
    }
    return result * sortOrder;
  };
};

let dataTable;

function populateTable(){
	let rows = 0;
	let dataArray = [];

	mergedData.features.sort(sortFeaturesByProperty('pws_name', 'asc')); // Sort ascending

	mergedData.features.forEach(feature => {
		if(combinedFilter.includes(feature.properties['pwsid']) || combinedFilter.length==0){
			if($('#data-table').is(':visible')){
				rows++;

				dataArray[rows-1] = [];
				//dataArray[rows-1].push('cb'); // = '<tr class="tr-'+feature.properties['pwsid']+'"><td class="col-'+feature.properties['pwsid']+'"><input type="checkbox" class="toggle" id="cb-'+feature.properties['pwsid']+'" /></td>';
				dataArray[rows-1].push(feature.properties['pws_name'] || '');
				dataArray[rows-1].push(feature.properties['pwsid'] || '');
				dataArray[rows-1].push('<a target="_blank" href="'+feature.properties['detailed_facility_report']+'">report</a>' || '');
				dataArray[rows-1].push(feature.properties['stusps'] || '');
				dataArray[rows-1].push(feature.properties['counties'] || '');
				dataArray[rows-1].push(feature.properties['gw_sw_code'] || '');
				dataArray[rows-1].push(feature.properties['source_water_protection_code'] || '');
				dataArray[rows-1].push(feature.properties['owner_type'] || '');
				dataArray[rows-1].push(feature.properties['primacy_type'] || '');
				dataArray[rows-1].push(feature.properties['is_wholesaler_ind'] || '');
				dataArray[rows-1].push(feature.properties['is_school_or_daycare_ind'] || '');
				dataArray[rows-1].push(feature.properties['symbology_field'] || '');
				dataArray[rows-1].push(feature.properties['epic_area_mi2'] || 0);
				dataArray[rows-1].push(feature.properties['open_health_viol'] || '');
				dataArray[rows-1].push(feature.properties['health_viols_5yr'] || 0);	
				dataArray[rows-1].push(feature.properties['groundwater_rule_healthbased_5yr'] || 0);	
				dataArray[rows-1].push(feature.properties['surface_water_treatment_rules_healthbased_5yr'] || 0);	
				dataArray[rows-1].push(feature.properties['lead_and_copper_rule_healthbased_5yr'] || 0);	
				dataArray[rows-1].push(feature.properties['radionuclides_and_revised_rad_rule_healthbased_5yr'] || 0);	
				dataArray[rows-1].push(feature.properties['inorganic_chemicals_healthbased_5yr'] || 0);	
				dataArray[rows-1].push(feature.properties['synthetic_organic_chemicals_healthbased_5yr'] || 0);	
				dataArray[rows-1].push(feature.properties['volatile_organic_chemicals_healthbased_5yr'] || 0);	
				dataArray[rows-1].push(feature.properties['total_coliform_rules_healthbased_5yr'] || 0);	
				dataArray[rows-1].push(feature.properties['stage_1_disinfectants_and_byproducts_rule_healthbased_5yr'] || 0);	
				dataArray[rows-1].push(feature.properties['stage_2_disinfectants_and_byproducts_rule_healthbased_5yr'] || 0);	
				dataArray[rows-1].push(feature.properties['health_viols_10yr'] || 0);	
				dataArray[rows-1].push(feature.properties['groundwater_rule_healthbased_10yr'] || 0);	
				dataArray[rows-1].push(feature.properties['surface_water_treatment_rules_healthbased_10yr'] || 0);	
				dataArray[rows-1].push(feature.properties['lead_and_copper_rule_healthbased_10yr'] || 0);	
				dataArray[rows-1].push(feature.properties['radionuclides_and_revised_rad_rule_healthbased_10yr'] || 0);	
				dataArray[rows-1].push(feature.properties['inorganic_chemicals_healthbased_10yr'] || 0);	
				dataArray[rows-1].push(feature.properties['synthetic_organic_chemicals_healthbased_10yr'] || 0);	
				dataArray[rows-1].push(feature.properties['volatile_organic_chemicals_healthbased_10yr'] || 0);	
				dataArray[rows-1].push(feature.properties['total_coliform_rules_healthbased_10yr'] || 0);	
				dataArray[rows-1].push(feature.properties['stage_1_disinfectants_and_byproducts_rule_healthbased_10yr'] || 0);	
				dataArray[rows-1].push(feature.properties['stage_2_disinfectants_and_byproducts_rule_healthbased_10yr'] || 0);	
				dataArray[rows-1].push(feature.properties['paperwork_viols_5yr'] || 0);	
				dataArray[rows-1].push(feature.properties['paperwork_viols_10yr'] || 0);	
				dataArray[rows-1].push(feature.properties['total_bwn'] || 0);
				dataArray[rows-1].push(feature.properties['total_pop'] || 0);
				dataArray[rows-1].push(feature.properties['epic_pop_density'] || 0);
				dataArray[rows-1].push(feature.properties['total_pop_pct_change_2011_2021'] || 0);
				dataArray[rows-1].push(feature.properties['mhi_pct_change_2011_2021'] || 0);
				dataArray[rows-1].push(feature.properties['hh_below_pov_per'] || 0);
				dataArray[rows-1].push(feature.properties['laborforce_unemployed_per'] || 0);
				dataArray[rows-1].push(feature.properties['mhi'] || 0);
				dataArray[rows-1].push(feature.properties['bachelors_per'] || 0);
				dataArray[rows-1].push(feature.properties['ageunder_5_per'] || 0);
				dataArray[rows-1].push(feature.properties['age_over_61_per'] || 0);
				dataArray[rows-1].push(feature.properties['poc_alone_per'] || 0);
				dataArray[rows-1].push(feature.properties['white_alone_per'] || 0);
				dataArray[rows-1].push(feature.properties['black_alone_per'] || 0);
				dataArray[rows-1].push(feature.properties['aian_alone_per'] || 0);
				dataArray[rows-1].push(feature.properties['napi_alone_per'] || 0);
				dataArray[rows-1].push(feature.properties['asian_alone_per'] || 0);
				dataArray[rows-1].push(feature.properties['hisp_alone_per'] || 0);
				dataArray[rows-1].push(feature.properties['other_alone_per'] || 0);
				dataArray[rows-1].push(feature.properties['mixed_alone_per'] || 0);
				dataArray[rows-1].push(feature.properties['a_int_identified_as_disadvantaged'] || 0);
				dataArray[rows-1].push(feature.properties['pw_int_pop_rpl_themes'] || 0);
				dataArray[rows-1].push(feature.properties['a_int_overall_cvi_score'] || 0);
				dataArray[rows-1].push(feature.properties['most_common_rate_tidy'].replace('Most people pay between ','').replace(' for water & sewer annually','').replace('Most people pay > ','Over ').replace('Most people pay < ','Under '));
				dataArray[rows-1].push(feature.properties['times_funded'] || 0);
				dataArray[rows-1].push(feature.properties['total_srf_assistance'] || 0);
				dataArray[rows-1].push(feature.properties['total_principal_forgiveness'] || 0);
				dataArray[rows-1].push(feature.properties['num_facilities'] || 0);
				dataArray[rows-1].push(feature.properties['total_permit_eff_viols'] || 0);
				dataArray[rows-1].push(feature.properties['total_open_usts'] || 0);
				dataArray[rows-1].push(feature.properties['total_facilities_w_rmps'] || 0);
				dataArray[rows-1].push(feature.properties['streams_303d_list'] || 0);


			}
		}
	});

	if(dataTable)
		dataTable.destroy();

	dataTable = new DataTable('#data-table', {
    	columns: [
			{title: 'Utility Name'},
			{title: 'Utility ID'},
			{title: 'EPA Facility Report'},
			{title: 'State'},
			{title: 'County'},
			{title: 'Source type'},
			{title: 'Source protection'},
			{title: 'Ownership'},
			{title: 'Authority'},
			{title: 'Wholesaler'},
			{title: 'Facility type (School or daycare)'},
			{title: 'Boundary type'},
			{title: 'Size (Area in square miles)', render: $.fn.dataTable.render.number( ',', '.', 2)},
			{title: 'Open violations'},
			{title: 'Health violations in the last 5 years', render: $.fn.dataTable.render.number( ',')},
			{title: 'Ground water rule violations in the last 5 years', render: $.fn.dataTable.render.number( ',')},
			{title: 'Surface water treatment rules violations in the last 5 years', render: $.fn.dataTable.render.number( ',')},
			{title: 'Lead & copper violations in the last 5 years', render: $.fn.dataTable.render.number( ',')},
			{title: 'Radionuclides violations in the last 5 years', render: $.fn.dataTable.render.number( ',')},
			{title: 'Inorganic chemicals violations in the last 5 years', render: $.fn.dataTable.render.number( ',')},
			{title: 'Synthetic organic chemicals violations in the last 5 years', render: $.fn.dataTable.render.number( ',')},
			{title: 'Volatile organic chemicals violations in the last 5 years', render: $.fn.dataTable.render.number( ',')},
			{title: 'Coliform violations in the last 5 years', render: $.fn.dataTable.render.number( ',')},
			{title: 'Stage 1 disinfectants violations in the last 5 years', render: $.fn.dataTable.render.number( ',')},
			{title: 'Stage 2 disinfectants violations in the last 5 years', render: $.fn.dataTable.render.number( ',')},
			{title: 'Health violations in the last 10 years', render: $.fn.dataTable.render.number( ',')},
			{title: 'Ground water rule violations in the last 10 years', render: $.fn.dataTable.render.number( ',')},
			{title: 'Surface water treatment rules violations in the last 10 years', render: $.fn.dataTable.render.number( ',')},
			{title: 'Lead & copper violations in the last 10 years', render: $.fn.dataTable.render.number( ',')},
			{title: 'Radionuclides violations in the last 10 years', render: $.fn.dataTable.render.number( ',')},
			{title: 'Inorganic chemicals violations in the last 10 years', render: $.fn.dataTable.render.number( ',')},
			{title: 'Synthetic organic chemicals violations in the last 10 years', render: $.fn.dataTable.render.number( ',')},
			{title: 'Volatile organic chemicals violations in the last 10 years', render: $.fn.dataTable.render.number( ',')},
			{title: 'Coliform violations in the last 10 years', render: $.fn.dataTable.render.number( ',')},
			{title: 'Stage 1 disinfectants violations in the last 10 years', render: $.fn.dataTable.render.number( ',')},
			{title: 'Stage 2 disinfectants violations in the last 10 years', render: $.fn.dataTable.render.number( ',')},
			{title: 'Non-health violations in the last 5 years', render: $.fn.dataTable.render.number( ',')},
			{title: 'Non-health violations in the last 10 years', render: $.fn.dataTable.render.number( ',')},
			{title: 'Boil water notices', render: $.fn.dataTable.render.number( ',')},
			{title: 'Population size', render: $.fn.dataTable.render.number( ',')},
			{title: 'Population density (people per square mile)', render: $.fn.dataTable.render.number( ',', '.', 0)},
			{title: 'Change in people in the last 10 years (%)', render: $.fn.dataTable.render.number( ',', '.', 2, '', '%')},
			{title: 'Change in income in the last 10 years (%)', render: $.fn.dataTable.render.number( ',', '.', 2, '', '%')},
			{title: 'Households below the poverty line (%)', render: $.fn.dataTable.render.number( ',', '.', 2, '', '%')},
			{title: 'Unemployment (%)', render: $.fn.dataTable.render.number( ',', '.', 2, '', '%')},
			{title: 'Annual median household income ($)', render: $.fn.dataTable.render.number( ',', '.', 0, '$' )},
			{title: 'Higher education attainment (%)', render: $.fn.dataTable.render.number( ',', '.', 2, '', '%')},
			{title: 'Children under 5 (%)', render: $.fn.dataTable.render.number( ',', '.', 2, '', '%')},
			{title: 'Elderly over 61 (%)', render: $.fn.dataTable.render.number( ',', '.', 2, '', '%')},
			{title: 'People of color (%)', render: $.fn.dataTable.render.number( ',', '.', 2, '', '%')},
			{title: 'White (%)', render: $.fn.dataTable.render.number( ',', '.', 2, '', '%')},
			{title: 'Black (%)', render: $.fn.dataTable.render.number( ',', '.', 2, '', '%')},
			{title: 'American Indian and Alaskan Native (%)', render: $.fn.dataTable.render.number( ',', '.', 2, '', '%')},
			{title: 'Native Hawaiian and Pacific Islanders (%)', render: $.fn.dataTable.render.number( ',', '.', 2, '', '%')},
			{title: 'Asian (%)', render: $.fn.dataTable.render.number( ',', '.', 2, '', '%')},
			{title: 'Latino/a (%)', render: $.fn.dataTable.render.number( ',', '.', 2, '', '%')},
			{title: 'Other (%)', render: $.fn.dataTable.render.number( ',', '.', 2, '', '%')},
			{title: 'Mixed race (%)', render: $.fn.dataTable.render.number( ',', '.', 2, '', '%')},
			{title: 'Disadvantaged area (%)', render: $.fn.dataTable.render.number( ',', '.', 2, '', '%')},
			{title: 'Social Vulnerability Index (%)', render: $.fn.dataTable.render.number( ',', '.', 2, '', '%')},
			{title: 'Climate Vulnerability Index (%)', render: $.fn.dataTable.render.number( ',', '.', 2, '', '%')},
			{title: 'Annual water and sewer bill'},
			{title: 'State revolving fund financing (2021 - 2025) - times received', render: $.fn.dataTable.render.number( ',')},
			{title: 'State revolving fund assistance (2021 - 2025) - amount received ($)', render: $.fn.dataTable.render.number( ',', '.', 2, '$' )},
			{title: 'State revolving fund principal forgiveness (2021 - 2025) - amount forgiven ($)', render: $.fn.dataTable.render.number( ',', '.', 2, '$' )},
			{title: 'Source water connections', render: $.fn.dataTable.render.number( ',')},
			{title: 'Pollution permits with breaches', render: $.fn.dataTable.render.number( ',')},
			{title: 'Underground storage tanks', render: $.fn.dataTable.render.number( ',')},
			{title: 'Risk management plan facilities', render: $.fn.dataTable.render.number( ',')},
			{title: 'Streams with impaired or threatened surface waters', render: $.fn.dataTable.render.number( ',')}
		],
		data: dataArray,
		lengthChange: false, //paging lenght controls
		pageLength: 100,
		searching: true, //table search box
		columnDefs: [{ className: 'first-col', targets: [0] }],
		//fixedColumns: true,
		//scrollCollapse: true,
	    //scrollX: true,
	    //scrollY: 300,
			/* Original table layout
		layout: {
			//topStart: 'search',
			topStart: {search: {placeholder: 'Search table...', text: ''}},
			topEnd: null}
		*/
		/* Revised table layout */
		layout: {
			//topStart: 'search',
			topStart: {search: {placeholder: 'Search table...', text: ''}},
			//topEnd: 'paging',
			bottomStart: {
				info: {	
				},
				paging: {
					buttons: 5
				}
			},
			topEnd: null, // removes default bottom pagination
			bottomEnd: null // removes default bottom pagination
		}
	});

	/*
	Disable geojson download when dataArray contains too many records
	Set limit at 5,000 to allow downloads for every state (Texas has over 4,500)
	*/
	if(dataArray.length > 5000){
		$('#file-geojson').prop('disabled', true);
	} else {
		$('#file-geojson').prop('disabled', false);
	}
	

}



function exportDataTableToGeoJSON(){

	let pwsIDs = [];
	const rows = dataTable.rows({ search: 'applied', order: 'applied' }).data().toArray();
	rows.forEach(row => {
		pwsIDs.push(row[1]);
	});
	$('#pws_ids').val(pwsIDs.join());
	$("#download-geojson-request").submit();
}

function exportDataTableToCSV(tableSelector, fileName = 'export.csv') {
    const table = $(tableSelector).DataTable();

    // Get column headers (skip checkbox column)
    const headers = table.columns().header().toArray()
        .map((th, i) => ({
            index: i,
            text: $(th).text().trim()
        }));

    // Get row data (filtered + ordered)
    const rows = table.rows({ search: 'applied', order: 'applied' }).data().toArray();

    const csvRows = [];

    // Header row
    csvRows.push(headers.map(h => csvEscape(h.text)).join(','));

    // Data rows
    rows.forEach(row => {
        const csvRow = headers.map(h => {
            const value = Array.isArray(row)
                ? row[h.index]
                : row[h.text];

            return csvEscape(value);
        });

        csvRows.push(csvRow.join(','));
    });

    downloadCSV(csvRows.join('\n'), fileName);
}

function csvEscape(value) {
    if (value === null || value === undefined) return '';

    const str = String(value);
    if (/[",\n]/.test(str)) {
        return `"${str.replace(/"/g, '""')}"`;
    }
    return str;
}

function downloadCSV(csvContent, fileName) {
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);

    const link = document.createElement('a');
    link.href = url;
    link.download = fileName;
    document.body.appendChild(link);
    link.click();

    document.body.removeChild(link);
    URL.revokeObjectURL(url);
}

function downloadGeoJSON(geoJSONContent, fileName) {
    const blob = new Blob([geoJSONContent], { type: 'application/json;charset=utf-8;' });
    const url = URL.createObjectURL(blob);

    const link = document.createElement('a');
    link.href = url;
    link.download = fileName;
    document.body.appendChild(link);
    link.click();

    document.body.removeChild(link);
    URL.revokeObjectURL(url);
}

function locationDependantUpdates(){
	/* Handle any control or content displayed based on geoFilterId */

	/* Boil Water Notice data is unavailable for most states */
	
	//enable the checkbox first 
	$('#boil-water-notices').prop('disabled',false);
	$('.bwn-disabled-txt').hide();
	$('label[for=boil-water-notices').css('color','');

	//show appropriate boil water notice tooltip based on state 
	$('.tt-notices').hide(); //hide all
	if(geoFilterId==''){ //no geo filter
		//for full U.S., disable checkbox
		$('#tt-notices').show();
		$('.bwn-content-wrapper').hide();
		$('#boil-water-notices').prop('disabled',true);
		$('.bwn-disabled-txt').show();
		$('label[for=boil-water-notices').css('color','#888');
	}
	else if(geoFilterId.slice(0,2)=='02')
		$('#tt-notices-ak').show();
	else if(geoFilterId.slice(0,2)=='05')
		$('#tt-notices-ar').show();
	else if(geoFilterId.slice(0,2)=='41')
		$('#tt-notices-or').show();
	else if(geoFilterId.slice(0,2)=='54')
		$('#tt-notices-wv').show();
	else if(geoFilterId.slice(0,2)=='35')
		$('#tt-notices-nm').show();
	else if(geoFilterId.slice(0,2)=='39')
		$('#tt-notices-oh').show();
	else if(geoFilterId.slice(0,2)=='44')
		$('#tt-notices-ri').show();
	else if(geoFilterId.slice(0,2)=='53')
		$('#tt-notices-wa').show();
	else if(geoFilterId.slice(0,2)=='29')
		$('#tt-notices-mo').show();
	else if(geoFilterId.slice(0,2)=='23')
		$('#tt-notices-me').show();
	//else if(geoFilterId.slice(0,2)=='12') //commenting out FL because currently no data available
	//	$('#tt-notices-fl').show();
	else if(geoFilterId.slice(0,2)=='25')
		$('#tt-notices-ma').show();
	else if(geoFilterId.slice(0,2)=='22')
		$('#tt-notices-la').show();
	else if(geoFilterId.slice(0,2)=='48')
		$('#tt-notices-tx').show();
	else { //any other state
		//for any other state, disable checkbox
		$('#tt-notices').show();
		$('.bwn-content-wrapper').hide();
		$('#boil-water-notices').prop('disabled',true);
		$('.bwn-disabled-txt').show();
		$('label[for=boil-water-notices').css('color','#888');
	}
}

function updateMoreFilterCount(){
	//called when filters are updated and when browser is resized, potentially hidding filter groups
	let moreFilterCount = 0;
	if($('.filter-1').hasClass('hidden'))
		moreFilterCount += filterGroupCounts.source;
	if($('.filter-2').hasClass('hidden'))
		moreFilterCount += filterGroupCounts.attributes;
	if($('.filter-3').hasClass('hidden'))
		moreFilterCount += filterGroupCounts.boundaries;
	if($('.filter-4').hasClass('hidden'))
		moreFilterCount += filterGroupCounts.compliance;
	if($('.filter-5').hasClass('hidden'))
		moreFilterCount += filterGroupCounts.population;
	moreFilterCount += filterGroupCounts.financial+filterGroupCounts.funding+filterGroupCounts.environmental;
	if(moreFilterCount>0) {
		$('.filter-count-group-10').html(moreFilterCount).parent().show();
		$("#container-menu-btn-10").addClass("has-filter");
	} else{
		$("#container-menu-btn-10").removeClass("has-filter");
	}
}

function resetByCategory(id){
	$('#loading-mask').show();

	const container = document.getElementById(id); // your div id
	const checkboxes = container.querySelectorAll('input[type="checkbox"]');
	const radios = container.querySelectorAll('input[type="radio"]');
	const selectboxes = container.querySelectorAll('select');
	const anchorbuttons = container.querySelectorAll('a.toggle');
	const divshidden = container.querySelectorAll('div.default-hidden');
	const ranges = container.querySelectorAll('input[type="range"]');
	

	checkboxes.forEach(checkbox => {
		if ($('#'+checkbox.id).hasClass('default-checked')) {
			if(!$('#'+checkbox.id).is(':checked'))
				$('#'+checkbox.id).prop('checked', true);
		}else{
			if ($('#'+checkbox.id).hasClass('map-checkbox')) //reset to default pws map
				map.setPaintProperty("pws", "fill-color", "rgb(78, 163, 36)");
			if($('#'+checkbox.id).is(':checked')){
				hideOptions(checkbox.id); //this will hide the range slider and histogram
				$('#'+checkbox.id).prop('checked', false);
			}
		}
	});

	
	radios.forEach(radio => {
		if ($('#'+radio.id).hasClass('default-checked')) {
			$('#'+radio.id).prop('checked', true);
		}
	});

	ranges.forEach(range => {
		$('#'+range.id).prop('min', 0);
		$('#'+range.id).prop('max', numBins-1);
		$('#'+range.id.replace('Slider','Input')).prop('min', 0);
		$('#'+range.id.replace('Slider','Input')).prop('max', 999);
		if(range.id.startsWith('min')){
			$('#'+range.id).val(0);
			$('#'+range.id.replace('Slider','Input')).val(0);
		} else {
			$('#'+range.id).val((numBins-1));
			$('#'+range.id.replace('Slider','Input')).val(99);
		}
	});

	selectboxes.forEach(selectbox => {
		if($('#'+selectbox.id).hasClass('min-select'))
			$('#'+selectbox.id).val($('#'+selectbox.id+' option:first').val());
		else if($('#'+selectbox.id).hasClass('max-select'))
			$('#'+selectbox.id).val($('#'+selectbox.id+' option:last').val());
	});

	anchorbuttons.forEach(anchorbutton => {
		//console.log(anchorbutton);
		if($('#'+anchorbutton.id).hasClass('toggle'))
			if($('#'+anchorbutton.id).hasClass('active'))
				$('#'+anchorbutton.id).removeClass('active');
		if ($('#'+anchorbutton.id).hasClass('default-checked')) {
			$('#'+anchorbutton.id).addClass('active');
			if ($('#'+anchorbutton.id).hasClass('wsb-box-first'))
				$('#'+anchorbutton.id).addClass('active-first');
		}
	});

	divshidden.forEach(divtohide => {
		$('#'+divtohide.id).hide();
	});
	
	if(!$('#boil-water-notices').is(':checked'))
		$('.bwn-content-wrapper').hide();


	$('.btn-apply-filters').trigger('click');  //just to close it
	setTimeout(() => {
		updateFilter();
		//console.log('reset filters for',id);
		$('#loading-mask').hide();
	},0);		
}


//this function returns an array of pwsids that meet the criteria for the sliders
function rangeFilter(key, min, max) {
	//console.log('rangeFilter:',key,min,max);
	//be sure to include values between 0 and 1
	if(min==1)
		min=0;

	return mergedData.features.reduce((ids, feature) => {
		const pwsid = feature.properties['pwsid'];
		const value = feature.properties[key];

		if (typeof value === "number" && value > min && value <= max) {
			ids.push(pwsid);
		}
		return ids;
	}, []);
}

//this function returns an array of pwsids that meet the criteria for check boxes
function checkBoxFilter(key, vals) {
  return mergedData.features.reduce((ids, feature) => {
    const pwsid = feature.properties['pwsid'];
    const value = feature.properties[key];

    if (vals.includes(value)) {
      ids.push(pwsid);
    }
    return ids;
  }, []);
}


function intersectArrays(arrays) {
  if (arrays.length === 0) return [];
  
  return arrays.reduce((acc, curr) => acc.filter(val => curr.includes(val)));
}

function unionArrays(arrays) {
  return [...new Set(arrays.flat())];
}

// equal interval bins
function getBreakpoints(values, numBins) {
    if (!Array.isArray(values) || values.length === 0) {
        throw new Error("Values must be a non-empty array.");
    }
    if (numBins < 1) {
        throw new Error("numBins must be at least 1.");
    }

    // Compute min and max
    const min = Math.min(...values);
    const max = Math.max(...values);

    // Handle edge case where all values are the same
    if (min === max) {
        return new Array(numBins + 1).fill(min);
    }

    const interval = (max - min) / numBins;
    const breaks = [];

    for (let i = 0; i <= numBins; i++) {
        breaks.push(min + i * interval);
    }

    return breaks;
}


// equal count bins
function getQuantileBreaks(values, numBins) {
    if (!Array.isArray(values) || values.length === 0) {
        throw new Error("Values must be a non-empty array.");
    }
    if (numBins < 1) {
        throw new Error("numBins must be at least 1.");
    }

    const sorted = [...values].sort((a, b) => a - b);
    const breaks = [sorted[0]];
    const n = sorted.length;

    for (let i = 1; i < numBins; i++) {
        const qIndex = Math.floor((i * n) / numBins);
        breaks.push(sorted[qIndex]);
    }

    breaks.push(sorted[n - 1]);
    return breaks;
}

// jenks natural breaks
function getJenksBreaks(values, numBins) {
    if (!Array.isArray(values) || values.length === 0) {
        throw new Error("Values must be a non-empty array.");
    }
    if (numBins < 1) {
        throw new Error("numBins must be at least 1.");
    }

    const data = [...values].sort((a, b) => a - b);
    const n = data.length;

    // Create matrices
    const lower = Array.from({ length: n + 1 }, () => Array(numBins + 1).fill(0));
    const variance = Array.from({ length: n + 1 }, () => Array(numBins + 1).fill(Infinity));

    // Initialize
    for (let i = 1; i <= numBins; i++) {
        lower[1][i] = 1;
        variance[1][i] = 0;
        for (let j = 2; j <= n; j++) {
            variance[j][i] = Infinity;
        }
    }

    const prefixSum = Array(n + 1).fill(0);
    const prefixSumSq = Array(n + 1).fill(0);

    for (let i = 1; i <= n; i++) {
        prefixSum[i] = prefixSum[i - 1] + data[i - 1];
        prefixSumSq[i] = prefixSumSq[i - 1] + data[i - 1] * data[i - 1];
    }

    function calcVariance(start, end) {
        const count = end - start + 1;
        const sum = prefixSum[end] - prefixSum[start - 1];
        const sumSq = prefixSumSq[end] - prefixSumSq[start - 1];
        return sumSq - (sum * sum) / count;
    }

    // Fill matrices
    for (let i = 2; i <= n; i++) {
        for (let j = 1; j <= numBins; j++) {
            for (let k = 1; k <= i; k++) {
                const v = calcVariance(k, i);
                if (variance[i][j] >= v + variance[k - 1][j - 1]) {
                    lower[i][j] = k;
                    variance[i][j] = v + variance[k - 1][j - 1];
                }
            }
        }
    }

    // Extract breaks
    const breaks = Array(numBins + 1).fill(0);
    breaks[numBins] = data[n - 1];

    let k = n;
    for (let j = numBins; j > 1; j--) {
        const idx = lower[k][j] - 1;
        breaks[j - 1] = data[idx];
        k = idx;
    }

    breaks[0] = data[0];
    return breaks;
}




// Because features come from tiled vector data,
// feature geometries may be split
// or duplicated across tile boundaries.
// As a result, features may appear
// multiple times in query results.
function getUniqueFeatures(features, comparatorProperty) {
	const uniqueIds = new Set();
	const uniqueFeatures = [];
	for (const feature of features) {
		const id = feature.properties[comparatorProperty];
		if (!uniqueIds.has(id)) {
			uniqueIds.add(id);
			uniqueFeatures.push(feature);
		}
	}
	return uniqueFeatures;
}

function uniqueByProperties(features) {
  const seen = new Set();
  return features.filter(obj => {
    const key = JSON.stringify(obj.properties);
    if (seen.has(key)) {
      return false;
    }
    seen.add(key);
    return true;
  });
}


function mergeGeoJSONById(geojsonA, geojsonB) {
  // Build lookup table for B's features by id
  const bMap = new Map(
    geojsonB.features.map(f => [f.properties.pwsid, f])
  );

  const mergedFeatures = [];

  // Merge features from A with B where ids overlap
  for (const featureA of geojsonA.features) {
    const id = featureA.properties.pwsid;
    const featureB = bMap.get(id);

    if (featureB) {
      // Merge properties; geometry from A (or change as needed)
      mergedFeatures.push({
        type: "Feature",
        id,
        geometry: featureA.geometry,
        properties: {
          ...featureA.properties,
          ...featureB.properties
        }
      });
      bMap.delete(id); // remove from map so we know which remain
    } else {
      // Unique to A
      mergedFeatures.push(featureA);
    }
  }

  // Add leftover features from B (those not in A)
  for (const featureB of bMap.values()) {
    mergedFeatures.push(featureB);
  }

  return {
    type: "FeatureCollection",
    features: mergedFeatures
  };
}
