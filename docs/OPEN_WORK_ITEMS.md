# Open Work Items
Known issues that have been discovered, which we know we need to come back to and address.


### Map
  - State Zoom upon state click
  - determine why states render 'blocky' instead of the whole state instantly on hover

### Filters
  - add remaining filters to the filter options:
    A checkbox selection on any of these should open up a nested option of sub filters
    - Health violations in the last 5 years
    - Health violations in the last 10 years
    - Non-health violations in the last 5 years
    - Non-health violations in the last 10 years
  - Filter Counter badges
    - currently showing, need to be configured to match design expectations
    
### Datasets
  - Basic mobile layout improved (Tier 4): non-sticky header, tighter padding, data source select overflow fixed
  - Further mobile polish may be needed on real devices (dev tools mobile emulation is approximate)

### Downloads
  - General formatting

### Mobile Issues
  - Map/Table view toggle is desktop-only (`hide-for-mobile` CSS) — intentional per current design; revisit if mobile map+table is scoped
  - Filter bar is desktop-only on mobile (`#container-map-ui-top { display: none }`) — mobile users currently have no filter access; open design question
  - [ ] Export button shows downloads icon
  - [ ] Report close button (X) renders and closes the overlay
  - [ ] Sidebar: not visible on mobile (desktop-only) — contact/feedback links inaccessible except via mobile menu
  - [ ] Print button on report overlay still renders (still uses `icon-print.png` PNG — confirm no broken image)

### application.css
  - confirm defaults
  - clean up/remove notes
  
### Images
  - make sure that all icons are valid .svgs with fill=currentColor set
  - make sure we have migrated away from .pngs and are using .svgs everywhere
    - Cleanup: remove all old images
  
### LookBook
  - determine best spot in docs to document LookBook
  - what it is
  - how to use
  - https://github.com/lookbook-hq/lookbook
  - If LookBook is fully related to Components we can use a COMPONENTS.md or a VIEWCOMPONENTS.md - whichever makes most sense.
  
### Data
  - Ensure that PR ENVs are copying an image of staging db (or even a subset)
  - data-health check” rake task that asserts the expected data exists
    - like “CartographicCounty.count > 0 and PublicWaterSystem.where.not(counties: [nil, '']).exists?”, etc. 
    - where would this report, slack channel?