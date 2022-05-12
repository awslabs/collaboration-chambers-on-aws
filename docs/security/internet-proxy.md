---
title: Internet Proxy
---

Scale-Out Computing on AWS filters all outbound internet access using a proxy server.

### Default Proxy Rules

All internet access is restricted unless explicitly allowed.

The rules can be customized before deployment by updating the following file:

**source/proxy/soca.conf**

This file can also be modified on the proxy at /etc/squid/soca.conf

After updating the proxy configuration you must restart the squid service:

`systemctl restart squid; systemctl status -l squid`
