# IIS Types

#### Table of Contents
1. [Overview](#overview)
1. [Requirements] (#requirements)
1. [Types] (#types)
  * [iis_site] (#iis_site)

## Overview

Create and manage IIS websites, application pools, and virtual applications.

## Requirements

- >= Windows 2012
- IIS installed

## Types

### iis_site

Enumerate all IIS websites:
* `puppet resource iis_site`<br />

Example output for `puppet resource iis_site 'Default Web Site'`
```
iis_site { 'Default Web Site':
  ensure   => 'present',
  app_pool => 'DefaultAppPool',
  ip       => '*',
  path     => 'C:\InetPub\WWWRoot',
  port     => '80',
  protocol => 'http',
  ssl      => 'false',
  state    => 'Started',
}
```

### iis_site attributes

* `name`<br />
(namevar) Web site's name.

* `path`<br />
Web root for the site.  This can be left blank, although IIS won't
be able to start the site.

* `app_pool`<br />
The application pool which should contain the site. Default: `DefaultAppPool`

* `host_header`<br />
A host header that should apply to the site.

* `protocol`<br />
The protocol for the site. Default `http`

* `ip`<br />
The IP address for the site to listen on. Default: `$::ipaddress`

* `port`<br />
The port for the site to listen on. Default: `80`

* `ssl`<br />
If SSL should be enabled. Default: `false`

* `state` <br />
Whether the site should be `Started` or `Stopped`.  Default: `Started`
