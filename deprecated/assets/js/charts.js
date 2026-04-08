function getPercentile(arr, percentile) {
    //console.log('*** getPercentile');
  if (arr.length === 0) return null;
  
  // Copy & sort ascending
  const sorted = [...arr].sort((a, b) => a - b);
  
  // Position in sorted array
  const index = (percentile / 100) * (sorted.length - 1);
  
  // If index is not an integer, interpolate between neighbors
  const lower = Math.floor(index);
  const upper = Math.ceil(index);
  
  if (lower === upper) return sorted[lower];
  
  const weight = index - lower;
  return sorted[lower] * (1 - weight) + sorted[upper] * weight;
}

function trimPercentiles(arr, lowPercent = 5, highPercent = 95) {
  if (arr.length === 0) return [];
  
  // Copy & sort ascending
  const sorted = [...arr].sort((a, b) => a - b);

  const lowIndex = Math.floor((lowPercent / 100) * sorted.length);
  const highIndex = Math.ceil((highPercent / 100) * sorted.length);

  // Return values between low and high percentile
  return sorted.slice(lowIndex, highIndex);
}

// Compute histogram once (full data, always shown)
function computeHistogram(data) {
    //console.log('*** start computeHistogram');
    let minVal = Math.min(...data);
    let maxVal = Math.max(...data);

    //console.log('min histogram value: ', minVal);

    let nBins = numBins; //global variable set in index.php
    if(maxVal<numBins){
        binSize = 1;
        nBins = Math.ceil(maxVal);
    }
    else
        binSize = Math.round((maxVal - minVal) / numBins);
    
    //console.log('hist min,max,nBins,binSize:',minVal,maxVal,nBins,binSize);

    const categories = [];
    let counts = [];

    for (let i = 0; i < nBins; i++) {
        const start = minVal + i * binSize;
        const end = start + binSize;
        if(start > maxVal || end > maxVal){
            nBins = i;
            break;
        }
        categories.push(`${start.toFixed(0)} - ${end.toFixed(0)}`);
    }

    if(nBins>0)
        counts = Array(nBins).fill(0);

    data.forEach(v => {
        const bin = Math.min(Math.floor((v - minVal) / binSize), nBins - 1);
        if(bin>=0)
            counts[bin]++;
    });
    //console.log(categories,counts);
    return { categories, counts };
}

function renderChart(id,hist){
    //console.log('*** start renderChart',id);
    //console.log(hist);
    const maxVal = getPercentile(hist.counts,98)*1.1; //for height of y axis
    let pntPadding = 0.12;
    let pntWidth = 5.5;
    if(hist.counts.length<50){
         pntPadding = 1-(hist.counts.length/50); //reduce padding for fewer bars
         pntWidth = pntWidth+pntPadding*10; //reduce padding for fewer bars
    }
    let chartHeight = 130;
    //set height of container
    $('#'+id).css('height',(chartHeight-10)+'px');

    if(hist.counts.length<2){ //still need the chart, but don't want it displayed
        chartHeight = 10; 

        //set height of container
        $('#'+id).css('height',(chartHeight-10)+'px');
    }

    // Initialize chart
    const chart = Highcharts.chart(id, {
        chart: { type: 'column', animation: false, height: chartHeight },
        credits: { enabled: false },
        title: { text: null },
        //xAxis: { categories: hist.categories, title: { text: 'Square Miles (bins)' } },
        xAxis: {
            categories: hist.categories,
            labels: {
                enabled: false // Disables the x-axis labels
            },
            title: { text: null } 
            },
        yAxis: { 
            labels: {
                enabled: false // Disables the x-axis labels
            },
            tickAmount: 2,
            max: maxVal,
            title: { text: null } 
        },
        legend: {
            enabled: false // This disables the entire legend
        },
        plotOptions: { 
            column: { 
                colorByPoint: true 
            } 
        },
        
        series: [{
            name: 'Water service areas',
            borderWidth: 0,
            pointWidth: pntWidth,
            pointPadding: pntPadding,
            groupPadding: 0,
            minPointLength: 5,
            maxPointWidth: 15, 
            data: hist.counts.map(c => ({ y: c, color: '#90caf9' }))
        }],
        tooltip: {
            //format: '<b>{point.key}</b>: <b>{y}</b> {series.name}'
            
            formatter: function() {
                // Access the category name using this.point.category or this.x
                const categoryName = this.point.key; //e.g. 0-1
                const range = categoryName.split(' - ').map(Number);
                const seriesName = this.series.name;
                const yValue = this.y;
                //console.log(range);

                return `<b>${range[0].toLocaleString('en-US')}</b> - <b>${range[1].toLocaleString('en-US')}</b>
                <br />${seriesName}: <b>${yValue.toLocaleString('en-US')}</b>`;
            }
            
        }
    });

    return chart;
}


function updateHighlight(histSlider,data) {
    //console.log('*** start updateHighlight');

    //filter histogram data for all data to non-zero values
    //except for pop-change and mhi-change because
    //these have negative numbers (percent change over time)
    if(histSlider != 'pop-change' && histSlider != 'mhi-change')
        data = data.filter(v => v > 0);
    
    //console.log(data);
    const hist = computeHistogram(data);
    const nBins = hist.counts.length;
    //console.log(hist,nBins);

    //this should only be true the first time since the value was initialized to numBins-1
    if($('#maxSlider-'+histSlider).val()*1 > nBins-1){
        //adjust slider max values
        $('#minSlider-'+histSlider).prop('max',nBins-1);
        $('#maxSlider-'+histSlider).prop('max',nBins-1);
        $('#maxSlider-'+histSlider).val(nBins-1);
    }

    // show histogram in case it was previously hidden
    $('#mapping-options-'+histSlider).show();
    // enable range controls in case previously disabled
    $('#minSlider-'+histSlider).prop('disabled',false);
    $('#maxSlider-'+histSlider).prop('disabled',false);

    //handle cases when nBins < 2 
    if(nBins<2){
        $('#minSlider-'+histSlider).prop('max',1);
        $('#maxSlider-'+histSlider).prop('max',1);
        $('#minSlider-'+histSlider).prop('disabled',true);
        $('#maxSlider-'+histSlider).prop('disabled',true);
        $('#maxSlider-'+histSlider).val(1);
        $('#mapping-options-'+histSlider).hide();
    }

    //always hiding mapping options for now
    $('#mapping-options-'+histSlider).hide();

    //console.log(data,hist);
    chart = renderChart('container-hc-'+histSlider,hist);

    let low = parseInt($('#minSlider-'+histSlider).val());
    let high = parseInt($('#maxSlider-'+histSlider).val());
    if (low > high) [low, high] = [high, low]; // swap if crossed
    $('#lowVal-'+histSlider).html(low);
    $('#highVal-'+histSlider).html(high);

    //console.log(hist.counts,low,high);

    if(nBins>1){
        // recolor bars
        chart.series[0].setData(hist.counts.map((c, i) => ({
            y: c,
            color: (i >= low && i <= high) ? '#1976d2' : '#90caf9'
        })), true);

        // update slider track highlight
        const percentLow = (low / (nBins - 1)) * 100;
        const percentHigh = (high / (nBins - 1)) * 100;
        $('#sliderRange-'+histSlider).css("left", percentLow + "%");
        $('#sliderRange-'+histSlider).css("width", (percentHigh - percentLow) + "%");
    } else {
        $('#sliderRange-'+histSlider).css("left", "0%");
        $('#sliderRange-'+histSlider).css("width", "100%");
    }

}

function inputChange(minMax,input){
    //console.log('*** start inputChange',minMax,input);

    //first remove formatting from both inputs
    $('#minInput-'+input).val($('#minInput-'+input).val().replaceAll(',',''));
    $('#maxInput-'+input).val($('#maxInput-'+input).val().replaceAll(',',''));

    //keep min less than max and max greater than min
    if(minMax=='min'){
        if($('#minInput-'+input).val()*1 >= $('#maxInput-'+input).val()*1)
            $('#minInput-'+input).val($('#maxInput-'+input).val()*1);
    }else{
        if($('#maxInput-'+input).val()*1 <= $('#minInput-'+input).val()*1)
            $('#maxInput-'+input).val($('#minInput-'+input).val()*1);
    }

    //keep min and max within allowed range
    if($('#minInput-'+input).val()*1 < 1)
        $('#minInput-'+input).val(1);
    if($('#maxInput-'+input).val()*1 > $('#maxInput-'+input).prop('max')*1)
        $('#maxInput-'+input).val($('#maxInput-'+input).prop('max'));

    let data = mergedData.features;
    const prop = sliderDataXwalk[input].prop;

    if(pwsFilterGeo.length>0) //apply geography filter if set
        data = data.filter(f => pwsFilterGeo.includes(f.properties.pwsid));
    data = data.map(feature => feature.properties[prop]); //iterate over features and return total_pop
    data = data.filter(v => v !== undefined && v !== null);  //filter out undefined
    //data = data.filter(v => Math.round(v) > 0);  //filter out 0s

    //pull the categories from the chart (the categories are the min and max for each histogram bar)
    const chartRanges = $('#container-hc-'+input).highcharts().series[0].data.map(d => d.category);

    const sliderID = '#'+minMax+'Slider-'+input; 
    const inputVal = $('#'+minMax+'Input-'+input).val()*1;

    chartRanges.forEach((range, index) => {
        const [start, end] = range.replaceAll(' ','').split('-').map(Number);
        if (index === 0 && inputVal <= end) 
            $(sliderID).val(index);
        else if (index === numBins - 1 && inputVal >= start) 
            $(sliderID).val(index);
        else if (inputVal >= start && inputVal <= end) 
            $(sliderID).val(index);
    });

    //adjust the min and max of the inputs based on the updated value: min and max can be equal
    $('#minInput-'+input).prop('max',$('#maxInput-'+input).val()*1);
    $('#maxInput-'+input).prop('min',$('#minInput-'+input).val()*1);

    updateHighlight(input,data);

    if(minMax=='min')
        $('#maxInput-'+input).trigger('blur'); //format the input numbers with commas
    else
        $('#minInput-'+input).trigger('blur'); //format the input numbers with commas


}

function sliderChange(minMax,slider){
    //console.log('*** start sliderChange',minMax,slider);
    //console.log('#maxSlider'+slider+' min,max,val:',$('#maxSlider-'+slider).prop('min'),$('#maxSlider-'+slider).prop('max'),$('#maxSlider-'+slider).val())

    //console.log(minMax,slider,$('#minSlider-'+slider).val(),$('#maxSlider-'+slider).val(),$('#minInput-'+slider).val(),$('#maxInput-'+slider).val());
    
    if($('#minSlider-'+slider).val()*1 >= $('#maxSlider-'+slider).val()*1)
        $('#minSlider-'+slider).val($('#maxSlider-'+slider).val()*1);
    if($('#maxSlider-'+slider).val()*1 <= $('#minSlider-'+slider).val()*1)
        $('#maxSlider-'+slider).val($('#minSlider-'+slider).val()*1);

    let data = mergedData.features;
    const prop = sliderDataXwalk[slider].prop;

    if(pwsFilterGeo.length>0) //apply geography filter if set
        data = data.filter(f => pwsFilterGeo.includes(f.properties.pwsid));
    data = data.map(feature => feature.properties[prop]); //iterate over features 
    data = data.filter(v => v !== undefined && v !== null);  //filter out undefined
    //data = data.filter(v => Math.round(v) > 0);  //filter out 0s
    
    if(data.length==0){ //e.g. boil water data is not available for all states
        hideOptions(slider);  //hide slider
        $('#'+slider).prop('checked',false);  //deselect checkbox
        alert('This filter currently does not apply to this state.');
        return;
    }

    updateHighlight(slider,data);
    //console.log(minMax,slider,$('#minSlider-'+slider).val(),$('#maxSlider-'+slider).val(),$('#minInput-'+slider).val(),$('#maxInput-'+slider).val());

    const sliderID = '#'+minMax+'Slider-'+slider; 

    let dataMin = Math.floor(Math.min(...data));
    let dataMax = Math.ceil(Math.max(...data));

    if(dataMax<1)
        dataMax = 1;

    //pull the categories from the chart (the categories are the min and max for each histogram bar)
    const chartRanges = $('#container-hc-'+slider).highcharts().series[0].data.map(d => d.category);
    
    let nBins = 1;
    let sliderRange = [0,1];  //default in case no bins

    if(chartRanges.length>1){  //at least 2 bars
        nBins = chartRanges.length;
        //parse the range at the slider position into two numbers
        sliderRange = chartRanges[$(sliderID).val()*1].split(' - ').map(Number)
    }

    let inputVal;
    //console.log(sliderRange);

    if(minMax=='min')
        if($(sliderID).val()*1==0 && sliderRange[0]>=0) //allow negative numbers for percent change over time
            inputVal = 1;
        else
            if($('#maxInput-'+slider).val().replaceAll(',','')*1 == sliderRange[1])
                inputVal = sliderRange[1]; //set to high end of range to allow user to set min and max range to the same value
            else
                inputVal = sliderRange[0]; //set to low end of range
    else 
        if($(sliderID).val()*1==0)
            inputVal = 1;
        else if($(sliderID).val()*1==nBins-1)
            inputVal = dataMax;
        else
            if($('#minInput-'+slider).val().replaceAll(',','')*1 == sliderRange[0])
                inputVal = sliderRange[0]; //set to low end of range to allow user to set min and max range to the same value
            else
                inputVal = sliderRange[1]; //set to high end of range

    //console.log(minMax,$(sliderID).val()*1,chartRanges,sliderRange,dataMax,nBins,inputVal)

    //set the input value
    $('#'+minMax+'Input-'+slider).val(inputVal);

    //format the input numbers with commas
    if($('#minInput-'+slider).val().replaceAll(',','')*1 > $('#maxInput-'+slider).val().replaceAll(',','')*1) {
        $('#minInput-'+slider).val(inputVal).trigger('blur');
        $('#maxInput-'+slider).val(inputVal).trigger('blur');
    } else 
        $('#'+minMax+'Input-'+slider).trigger('blur'); 
    
    //set the input min prop for data with negative numbers
    if(dataMin<0)
        $('#minInput-'+slider).prop('min',dataMin);

    //set the input max prop 
    $('#maxInput-'+slider).prop('max',dataMax);

    //adjust the min and max of the inputs based on the updated value: min and max can be equal
    $('#minInput-'+slider).prop('max',$('#maxInput-'+slider).val().replaceAll(',','')*1);
    $('#maxInput-'+slider).prop('min',$('#minInput-'+slider).val().replaceAll(',','')*1);

    //console.log(minMax,slider,$('#minSlider-'+slider).val(),$('#maxSlider-'+slider).val(),$('#minInput-'+slider).val(),$('#maxInput-'+slider).val());


}

