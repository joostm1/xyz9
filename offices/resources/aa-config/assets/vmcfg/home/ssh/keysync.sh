
#!/bin/bash
# Get & put ssh keys in my keyvault

kv="xyz9-kv"
id="xyz9-sshkeysync"
debug=0
n=0

azsshkey ()
{
	[[ $debug == 0 ]] && set +x || set -x

	# Create arrays for local- and kv-based fingerprints
	kvfplist=() && localfplist=()

	# Populate the KV array with of all of OUR(id) fingerprints in KV
	kvfplist+=($(az keyvault secret list --vault-name $kv \
		--query "[?contains(name,'$id')].tags.fingerprint" --output tsv))

	# Upload all local private key files that are not in the KV yet
	for f in $@
	do
		# see if the file contains a private key
		keyfile=$(file $f 2>/dev/null | awk -F: 'tolower($0) ~ /private key/ { print $1 }')
		if [[ -f $keyfile ]]; then
			printf "Checking file '$keyfile'.. please provide password when asked ..\n"
			fingerprint=$(ssh-keygen -y -f $keyfile | ssh-keygen -l -f - | awk -F '[ :]' '{ print $3 }')

			if [[ ! -z $fingerprint ]]; then
				# Compose an array of local fingerprints
				localfplist+=($fingerprint)

				# See if this key is in KV already. 
				# bash '=~' doesn't seem to work for this..
				if [[ $(echo ${kvfplist[@]} | grep -w $fingerprint) == ""  ]]; then
					az keyvault secret set \
						--vault-name $kv \
						--name "$id-$RANDOM" \
						--file $keyfile \
						--encoding ascii \
						--tags filename=$keyfile fingerprint=$fingerprint > /dev/null
					printf "Added '$keyfile' to vault $kv\n"
				else
					printf "$keyfile is already in vault $kv\n"
				fi
			else
				printf "Could not get fingerprint for $keyfile\n"
			fi
			printf "\n"
		fi
	done
	printf "\n"

	# Download all our private key files that are not here yet
	for kvkeyname in $(az keyvault secret list --vault-name $kv --query "[?contains(name,'$id')].name" --output tsv)
	do
		# Get KV fingerprint & filename
		fingerprint=$(az keyvault secret show --vault-name $kv --name $kvkeyname --query 'tags.fingerprint' --output tsv)
		keyfile=$(az keyvault secret show --vault-name $kv --name $kvkeyname --query 'tags.filename' --output tsv)

		# Download the keyfile if not local already
		if [[ $(echo ${localfplist[@]} | grep -w $fingerprint) == "" ]]; then
			if [[ ! -f $keyfile ]]; then
				az keyvault secret download --vault-name $kv --name $kvkeyname --file $keyfile && \
					chmod u=rw,g=,o= $keyfile > /dev/null && \
					printf "fingerprint '$fingerprint' added in $keyfile\n"
			else
				printf "keyfile '$keyfile' has a different name. Crazy you!\n"
			fi
		else
			printf "fingerprint '$fingerprint' already here\n"
		fi
	done
}

# main ()
azsshkey *

