# How to add Nginx GeoIP module in Ubuntu

First add the nginx stable repo:

	sudo add-apt-repository ppa:nginx/stable

Then run apt update:

	sudo apt-get update

And get the nginx geoip module:

	sudo apt-get install nginx-module-geoip

This will download and load the module to /usr/lib/nginx/modules

To load the nginx module,

	open nginx.conf:

	sudo nano /etc/nginx/nginx.conf

add add below in the main context:

	load_module "modules/ngx_http_geoip_module.so";

The module will be loaded, when you reload the configuration or restart nginx.

*To dynamically “unload” a module, comment out or remove its load_module directive and reload the nginx configuration.*