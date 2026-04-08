<div id="container-sidebar" class="container-nav-panel hide-for-mobile">
		<div class=""><a href="javascript:void(0)" id="toggle-button" class="btn-toggle-panel open"></a></div>

		<div class="container-logo">
			<img src="assets/img/logo-drinking-water-explorer.png" />
		</div>
		<div class="container-intro hide-when-collapsed-fade">
			<h2>Drinking Water Explorer</h2>
			<p>Use this tool to view and compare public water systems across the<br/>country.</p>
		</div>
		<div class="container-sidebar-nav">
			<ul class="sidebar-nav">
				<li class="nav-1"><a href="javascript:void(0);" onclick="showMap('map');" class="nav-item nav-1 nav-map active"><span class="hide-when-collapsed">Explore the Map</span></a></li>
				<li class="nav-2"><a href="javascript:void(0);" onclick="showSection('datasets');" class="nav-item nav-2 nav-datasets"><span class="hide-when-collapsed">Datasets</span></a></li>
				<li class="nav-3"><a href="https://tech-team-data.s3.us-east-1.amazonaws.com/national-dw-tool/public-data-downloads/EPIC's+Drinking+Water+Explorer+Tool+-+Methodology.pdf" target="_blank" class="nav-item nav-3 nav-documentation"><span class="hide-when-collapsed">Documentation</span><img src="assets/img/icon-ext-link.png" class="inline" /></a></li>
				<li class="nav-4"><a href="javascript:void(0);" onclick="showSection('downloads');" class="nav-item nav-4 nav-downloads"><span class="hide-when-collapsed">Downloads</span></a></li>
			</ul>
		</div>

		<div class="container-sidebar-bottom">
			<div class="container-epic-logo">
				<img src="assets/img/EPIC-logo.png" />
			</div>
			<p style="margin-top:5px;">(<a href="https://creativecommons.org/share-your-work/cclicenses/" target="_blank">cc</a>) <span class="hide-when-collapsed">Environmental Policy<br/>Center </span>(EPIC)</p>
			<div style="margin:30px 0px;">
				<p><a href="https://github.com/Environmental-Policy-Innovation-Center/national-dw-tool-public" target="_blank">Github</a><img src="assets/img/icon-ext-link.png" class="inline" /></p>
				<p><a href="https://docs.google.com/forms/d/e/1FAIpQLSdj-JcAmFNHnyEGoou74kyL_R1YOUtsFG4dKlYl0TWWwkUcrg/viewform" target="_blank">Feedback</a><img src="assets/img/icon-ext-link.png" class="inline" /></p>
			

				<p class="hide-when-collapsed">
					<a href="mailto:watertool@policyinnovation.org">Contact EPIC</a><img src="assets/img/icon-email.png" class="inline" />
				</p>

				<p class="show-when-collapsed hide-when-expanded" style="display:none;">
					<a href="mailto:watertool@policyinnovation.org">Contact</a><img src="assets/img/icon-email.png" class="inline" style="width: 12px; margin-bottom: 0px;" />
				</p>
			</div>

			<p><strong>Last updated on:</strong><br /><span style="font-size: 80%;" class="last-updated-date"><?php echo $lastupdatedt; ?></span></p>

		</div>

	</div>