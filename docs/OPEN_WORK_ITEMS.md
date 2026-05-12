# Open Work Items
Known issues that have been discovered, which we know we need to come back to and address.

---

### Map
  - Fix fly to zooms (48) now that map fills full page
  - State Zoom upon state click
  - determine why states render 'blocky' instead of the whole state instantly on hover

### Filters
  - Filter Counter badges
    - currently showing, need to be configured to match design expectations
      - (each box/radial that is checked counts as 1)
  - Add missing info tool tips _(DID MUCH OF THIS, STILL MISSING SOME SECTIONS)_
    - to the 'headline' category types: Primary type, Type, Violatons, etc.
    - to the filter category types: Wholesaler
      - tooltip copy IS NOW defined in tooltips.yml file
  - Annual Water and sewer bill 
    - Show systems with no available information on rates (MISSING CHECKBOX OPTION)
    - this needs to be pulled out of where it currently is (part of the scale choices) and be its own check box
      - confirm behavior on that first
  - Add Boil Water Summary filtering functionality
  - Add place_name search funcitonality
  
### Historgrams
  - get confirmation on expected behavior for histogram sliders for Health Violation sub Categories
    - When do they open, when do they close, what should things look like on first load (range)

  - OVERALL Styline Needed -> buckets, scaling, hover feedback, etc. (see mock)
   
   
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
  
### HTML
  - label ids and potentially classes to reflect our filtering level taxonomy verbiage as defined in TAXONOMY.md
  - Address and fix for accessibility concners - aria tags, semantic naming, using correct elements, etc.
  
### Assets
  - make sure that all icons are valid .svgs with fill=currentColor set
  - make sure we have migrated away from .pngs and are using .svgs everywhere (except for logos)
    - Cleanup: remove all old images
  - deprecate and delete water_tool.css - as referenced in TAILWIND_MIGRATION.md
  
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
    
### Other
  - with a large set of filters, our URLs can get very long - determine a potential strategy for solving this
    - already tried, a messy mapping strategy, but could otentially try again
  - Ensure Mapbox access token currently exposed in request/response data visible in browser devtools for all ENVS
    - hide this in staging, pr, and prod!
  - PR teardowns - ensure that they are getting torn down!
    - auto close PRs after 2 weeks
    
    
### Documentation
  - EVENTUALLY - remove temporary docs
  - update docs that will persist, ensuring accuracy
  - document..
    - what it means to be 'mobile friendly'
    - what it meands to follow a11y best practices and standards