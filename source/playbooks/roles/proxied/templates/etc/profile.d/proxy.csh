setenv ProxyPrivateDnsName proxy.{{Domain}}
proxy_url="http://${ProxyPrivateDnsName}:3128/"

setenv HTTP_PROXY  $proxy_url
setenv HTTPS_PROXY $proxy_url
setenv http_proxy  $proxy_url
setenv https_proxy $proxy_url

# No proxy:
# Comma separated list of destinations that shouldn't go to the proxy.
# - EC2 metadata service
# - Private IP address ranges (VPC local)
setenv NO_PROXY "{{NoProxy}}"
setenv no_proxy $NO_PROXY

setenv REQUESTS_CA_BUNDLE /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem
