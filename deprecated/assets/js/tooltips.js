
// With the above scripts loaded, you can call `tippy()` with a CSS
// selector and a `content` prop:

tippy('#tt-source', {
content: 'The source of your water can affect its quality and safety. Most of the drinking water in the U.S. comes from reservoirs, lakes, rivers, or water under the ground.',
});

tippy('#tt-protection', {
content: 'Source water protections safeguard, maintain, and improve the quality and/or quantity of drinking water. Please note the availability of this data varies by state.',
});

tippy('#tt-wholesaler', {
content: 'Wholesalers treat source water and then provide some or all of that water to other public water systems.',
});

tippy('#tt-type', {
content: 'Service area boundaries show the extent of the area served by a water system. Modeled systems are estimated based on the quality of available data.',
});

tippy('#tt-violations', {
content: 'Violations occur when a water system fails to meet drinking water standards. Systems with violations, especially health-based ones, can face penalties and are required to notify customers.',
});

tippy('.tt-groundwater-rules', {
content: 'The ground water rule provides protection against microbial pathogens in public water systems using ground water sources.',
});

tippy('.tt-surface-water-rules', {
content: 'The surface water treatment rules require water systems to filter and disinfect surface water sources.',
});

tippy('.tt-lead-copper', {
content: 'The lead and copper rule requires public water systems to take action when they fail to meet the rules requirements such as corrosion control, public notifications, or service line replacement.',
});

tippy('.tt-radionuclides', {
content: 'Violations for inorganic chemicals in drinking water involve exceeding legal limits for contaminants like arsenic, nitrate, and lead.',
});

tippy('.tt-inorganic-chemicals', {
content: 'Violations for inorganic chemicals in drinking water involve exceeding legal limits for contaminants like arsenic, nitrate, and lead.',
});

tippy('.tt-synthetic-organic-chemicals', {
content: 'Violations for synthetic organic chemicals occur when the maximum contaminant levels are exceeded.',
});

tippy('.tt-volatile-organic-chemicals', {
content: 'Violations for volatile organic chemicals occur when the maximum contaminant levels are exceeded.',
});

tippy('.tt-coliform', {
content: 'Violations for coliforms occur when more than five percent of samples taken from public water systems contain coliforms.',
});

tippy('.tt-stage-1-disinfectants', {
content: 'Violations for stage 1 disinfectants occur when public water systems exceed the maximum containment levels for disinfectants and byproducts.',
});

tippy('.tt-stage-2-disinfectants', {
content: 'Violations for stage 2 disinfectants occur when public water systems exceed the maximum exposures for total trihalomethanes and haloacetic acids, byproducts in water disinfected with chlorine or chloramine.',
});

tippy('#tt-notices', {
content: 'Boil water notices are issued when there is a potential for bacterial contamination in the tap water, often due to issues like loss of pressure from main breaks, equipment failure, or flooding. These can be planned or unplanned.',
});

tippy('.tt-size', {
content: 'The Environmental Protection Agency classifies public water systems into five size categories based on population served.',
});

tippy('#tt-disadvantaged-area', {
content: 'The Climate and Economic Justice Screening Tool identified areas that are overburdened and underserved.',
});

tippy('#tt-social-vulnerability-index', {
content: 'The Centers for Disease Control Social Vulnerability Index shows which communities are especially at risk during public health emergencies or other disasters.',
});

tippy('#tt-climate-vulnerability-index', {
content: 'The US Climate Vulnerability Index identifies communities that face the greatest challenges from climate change.',
});

tippy('#tt-financial', {
content: 'Annual water and sewer bill data comes from the Census. Data here represents the mode or most common rate paid by the service population and does not represent direct water system rates.',
});

tippy('#tt-funding', {
content: 'The Drinking Water State Revolving Fund program assists public water systems in financing the cost of drinking water infrastructure projects needed to achieve or maintain compliance with Safe Drinking Water Act. Data here comes from EPA&rsquo;s SRF Portal.',
});

tippy('#tt-print-report', {
content: 'Print report',
});

tippy('#tt-close-report', {
content: 'Close report',
});

tippy('.file-geojson', {
content: 'GeoJSON files can be exported here by state and additional filtering.  Full data downloads are also available on the Downloads page.'
});

tippy('#tt-watershed-hazards', {
content: 'These filters can be used to evaluate potential environmental hazards within the watershed the system is pulling from.'
});

tippy('#tt-source-water-connections', {
content: "This variable shows the number of source water connections, ground and surface, this water system has, as found in EPA's How's My Waterway."
});

tippy('#tt-pollution-permits-w-breaches', {
content: "Discharge points are permitted to regulate contaminants released into the environment. This shows the number of permits with violations in the water system's source watershed."
});

tippy('#tt-underground-storage-tanks', {
content: "Underground storage tanks are often safe, but some may leak into the environment. This shows the number of active underground storage tanks in the water system's source watershed."
});

tippy('#tt-risk-mgnt-plan-facilities', {
content: "Facilities that handle hazardous substances are required to have a risk management plan. This shows the number of facilities with risk management plans in the water system's source watershed."
});

tippy('#tt-streams-impared-threatened', {
content: "Depending on water quality measurements, a waterbody may be impaired or threatened. This shows the number of impaired or threatened streams within a water system's source watershed. Note, there may be state to state differences in this data."
});

tippy('#tt-link-example', {
content: 'Tooltip example with a <a href="#" target="_blank">link</a> and <em>light</em> <strong>html formatting</strong> should the need ever arise.',
allowHTML: true,
interactive: true,
});