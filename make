#!/usr/bin/env bash

set -euo pipefail

die() {
	>&2 echo "FATAL: ${@:-UNKNOWN ERROR}"
	exit 1
}

make_key() {
	#openssl genrsa 4096
	openssl ecparam -genkey -name prime256v1 | openssl pkey -aes256 -passout pass:"${1}"
}

make_cnf() {
	cat <<- EOF
	[ req ]
	distinguished_name              = req_dn
	default_md                      = sha256
	req_extensions			= req_ext
	
	[ req_dn ]
	countryName                     = Country Name
	stateOrProvinceName             = State or Province Name
	localityName                    = Locality Name
	0.organizationName              = Organization Name
	organizationalUnitName          = Organizational Unit Name
	
	countryName_default             = US
	stateOrProvinceName_default     = California
	localityName_default            = Palo Alto
	0.organizationName_default      = VMware, Inc
	organizationalUnitName_default  = Tanzu Labs
	
	[ req_ext ]
	# A critical extension means that the requester or certificate authority
	# has requested that any entity that is attempting to verify the certificate
	# must understand and implement the extension or must fail verification
	basicConstraints                = critical,CA:false
	keyUsage                        = digitalSignature, keyEncipherment
	extendedKeyUsage                = serverAuth
	subjectKeyIdentifier            = hash
	subjectAltName                  = @alt_names
	
	[ alt_names ]
	DNS.1                           = $(echo "${1}" | sed 's/\..*//')
	DNS.2                           = ${1}
	EOF
}

rand_pass() {
	dd if=/dev/random bs=128 count=1 2>/dev/null | sha256sum | cut -d\  -f 1 | sed 's/^\(.\{20\}\).*/\1/'
}

for site in $(cat sites); do
	mkdir -p "${site}"
	for device in $(cat devices); do
		host="${device}-${site}.mckesson.com"
		dir="${site}/${device}"
		mkdir -p "${dir}"

		keyfile="${dir}/${host}.key.enc"
		csrfile="${dir}/${host}.csr"
		cnffile="${dir}/${host}.cnf"
		pass="$(rand_pass)"
		[ -r "${keyfile}" ] || { make_key "${pass}" > "${keyfile}" || die "Could not create private key."; echo "${keyfile}:${pass}" >> passwords.key; }
		[ -r "${cnffile}" ] || make_cnf "${host}" > "${cnffile}"
		[ -r "${csrfile}" ] || openssl req -new -key "${keyfile}" -passin "pass:${pass}" -config "${cnffile}" -batch -out "${csrfile}"
	done
done
