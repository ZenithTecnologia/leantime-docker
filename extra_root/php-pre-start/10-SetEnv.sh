#!/bin/bash

ACCEPTED_PARAMETERS=$(curl -sSL https://raw.githubusercontent.com/Leantime/leantime/refs/tags/v3.5.1/config/sample.env | grep '^LEAN_.*' | awk -F= '{ print $1 }' | tr -d ' ' | tr '\n' '|' | rev | cut -c2- | rev)

env | while IFS= read -r line; do
	value=${line#*=}
	name=${line%%=*}
	if [ ! -z "${value}" ]; then 
		eval "
			case ${name} in
				${ACCEPTED_PARAMETERS})
					echo \">>>>> Set up ${name} environment variable on Apache <<<<<\"
					echo \"SetEnv ${name} \"${value}\"\" >> /etc/httpd/conf.d/s2i-setenv.conf
			esac
		"
	fi
done

