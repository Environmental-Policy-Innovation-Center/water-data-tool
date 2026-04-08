# Drinking Water Explorer Hosting Notes

## Transfer of Development and Hosting Memo

This document provides notes and specifications for the transfer of development and hosting the Drinking Water Explorer web tool from CNT to EPIC.

# AWS

CNT uses AWS for website and database hosting, primarily EC2 and RDS.  These specifications do not have to be replicated precisely but are intended as guidance.

* We use a single EC2 instance to host our web applications  
  * Platform: Linux (Ubuntu 22\)  
  * Type: m7i.large  
  * Region: US-East  
  * Software installed:  
    * Apache 2.4  
    * PHP 8.1  
      * pgsql extension  
    * Python 3.10  
      * geojson 3.1.0  
      * psycopg2 2.9.2  
      * requests 2.32.5  
* We use an RDS cluster running 2 or more instances (1 write instance, 1 or more read replica instances)  
  * Type: Aurora PostgreSQL  
  * Engine version: 15.12  
  * Region: US-East  
  * Instance class: db.t4g.medium  
  * PostgreSQL extensions installed: postgis, postgis\_raster, plpgsql   
  * Security: RDS instances are assigned to a security group that is open to specific IP addresses, including the IP address of our EC2 instance and any IP addresses of the development team  
  * Auto scaling policies: We have autoscaling policies that will add/remove read replicas when database connections reach 35 and/or when CPU utilization reaches 75%

# Database

CNT has provided an SQL script to create the database tables used by the Drinking Water Explorer.  The database consists of:

* 12 tables created by the Python script that imports data provided by EPIC (cejst, cvi, ejscreen, epa\_sabs, epa\_sabs\_geoms, epa\_sabs\_xwalk, national\_bwn\_highlevel\_summary, pwsid\_npdes\_usts\_rmps\_imp, pwsid\_funded\_highlevel\_summary, sdwis\_viols, svi, xwalk\_pct\_change\_10yr)  
* The 2022 [U.S. Census Cartographic Boundaries](https://www.census.gov/geographies/mapping-files/time-series/geo/cartographic-boundary.html) (1:500K) for State, County and Place (cartographic\_places2022, cartographic\_counties2022, cartographic\_state2022)  
* epa\_sabs\_points: EPA SABs centroids (via [ST\_PointOnSurface](https://postgis.net/docs/ST_PointOnSurface.html)) derived from epa\_sabs\_geoms and the State that intersects the centroid  
* place\_sabs\_xtab: a table containing the pwsid, the intersecting Census place ID, and the fraction of both the SAB and the Place that intersect  
* pws\_counties: a table derived from epa\_sabs\_geoms and cartographic\_counties2022, containing each pwsid and the names of the counties that the sab intersects, used to populate the County column of the table view  
* file\_import\_tracker: a table that logs data imports (populated by Python script) and intended to be used to compare against a JSON file to determine whether any data files have been updated since last imported  
* wdt\_mvt: a table for cached Mapbox Vector Tile data (populated by PHP)

# Docker

CNT uses Docker for local development.  Each developer has been responsible for setting up their own Container to match our EC2 instance.  We do not replicate our PostgreSQL database locally but rather add our local IP addresses to our RDS security group inbound rules allowing our local development environments to connect to the database on our RDS instance.  This practice saves us the effort of replicating large datasets, however when database changes are made that require changes to SQL run by the application, code changes need to be made and pushed to the repository so that other developers can avoid SQL errors.

# .gitignore

CNT uses the .gitignore file to keep database credentials and endpoints private.  There are two files with credentials that are required but excluded from the repository.  

* dbFunctions.inc.php  
* data/credentials.py

Included in the repository are templates so that you can create your own versions of these files with prompts in square brackets (e.g. \[YOUR HOST \- RDS WRITER INSTANCE ENDPOINT\]).

# Mapbox

The Drinking Water Explorer uses Mapbox, requiring a Mapbox account.  Once an account is set up, you will need to update the code to use an access token under your account and either a public style or a style under your account.  

CNT uses an access token open to the public while in development to avoid issues when developing locally, but switches to a URL restricted access token when a tool goes live.  This prevents others from using our account and incurring usage costs that we would be required to pay. 

The Drinking Water Explorer currently uses a minimal Mapbox style (base map) that CNT created for past projects via [Mapbox Studio](https://docs.mapbox.com/studio-manual/guides/).  This style will not be accessible once the account is changed, so the style URL will need to be changed to either a default Mapbox style or a custom style under your account.

CNT does not use Mapbox as a data host, but rather as the mapping platform, primarily only [Mapbox GL JS](https://docs.mapbox.com/mapbox-gl-js/guides/) library and APIs for UI/UX, geocoding, etc. so there will not be any data to move from the CNT Mapbox account.  The Mapbox Vector Tiles are generated by the application code and stored in the PostgreSQL database.

# Google Analytics

CNT generally adds Google Analytics tracking code tied to our Google Analytics account to track usage once an application goes live.  The Google Analytics tracking code will need to be changed to a new tracking code.

