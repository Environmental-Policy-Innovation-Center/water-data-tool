# Open Work Items
Known issues that have been discovered, which we know we need to come back to and address.

---

### Map
  - State Zoom upon state click
  - determine why states render 'blocky' instead of the whole state instantly on hover

### Filters
  - Filter Counter badges
    - currently showing, need to be configured to match design expectations
  - Add missing info tool tips _(to match legacy app)_
    - to the 'headline' category types: Primary type, Type, Violatons, etc.
    - to the filter category types: Wholesaler
    - tooltip copy defined in tooltips.yml file
    
### Historgrams
  - get confirmation on expected behavior for histogram sliders for Health Violation sub Categories
    - When do they open, when do they close, what should things look like on first load (range)
  - Implement full set of histograms
    
### Data Table
  - Add remaining sort options
    
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
  - confirm defaults, branding
  - clean up/remove notes
  
### Assets
  - make sure that all icons are valid .svgs with fill=currentColor set
  - make sure we have migrated away from .pngs and are using .svgs everywhere
    - Cleanup: remove all old images
  - Install and use the 
  
### LookBook
  - determine best spot in docs to document LookBook
  - what it is, and how to use
  - link docs: https://github.com/lookbook-hq/lookbook
  - If LookBook is fully related to Components we can use a COMPONENTS.md or a VIEWCOMPONENTS.md - whichever makes most sense.
  
### Data
  - Ensure that PR ENVs are copying an image of staging db (or even a subset)
  - data-health check” rake task that asserts the expected data exists
    - like “CartographicCounty.count > 0 and PublicWaterSystem.where.not(counties: [nil, '']).exists?”, etc. 
    - where would this report, slack channel?