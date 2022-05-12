export ProxyPrivateDnsName=proxy.{{Domain}}
proxy_url="http://${ProxyPrivateDnsName}:3128/"

export HTTP_PROXY=$proxy_url
export HTTPS_PROXY=$proxy_url
export http_proxy=$proxy_url
export https_proxy=$proxy_url

# No proxy:
# Comma separated list of destinations that shouldn't go to the proxy.
# - EC2 metadata service
# - Private IP address ranges (VPC local)
export NO_PROXY="{{NoProxy}}"
export no_proxy=$NO_PROXY

export REQUESTS_CA_BUNDLE=/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem
