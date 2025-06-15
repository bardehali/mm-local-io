require 'openssl'

if Rails.env.production?
  OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_PEER
  #OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
  OpenSSL::SSL::SSLContext::DEFAULT_CERT_STORE.add_file("/etc/ssl/certs/ca-certificates.crt")
end
