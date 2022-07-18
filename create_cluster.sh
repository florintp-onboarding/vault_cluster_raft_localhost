#!/bin/bash 

###  VARIABLES BLOCK
export hash_padding="#############"
export a_workingdir="$(pwd)/vault" 
export a_basedir=$(basename "${a_workingdir}")
export a_maindir=$(dirname "${a_workingdir}")
#Interface is not used yet.
##export a_ifname='en0'
#export a_ipaddr=$(ifconfig ${a_ifname}|grep 'broadcast'|awk '{print $2}')
#####

#Number of Vault cluster nodes (n-1) as the transit server will not make part of the cluster.
export a_vaultcnt=6
# TESTWINDOW is the time reserved for testing in seconds. (default is '120'))
export TESTWINDOW=120
# DEBUG initialized with a value greater than '0' will make the script prompt for every major activity. (default is '0')
export DEBUG=1
# RETRYS is the maximum number of retries on validating the correct start of the Vault server.( default is '6')
export RETRYS=6
###

### FUNCTION BLOCK
function create_vault_conf()
{
  echo "${hash_padding}===${FUNCNAME[*]}==== "
  cd "${a_workingdir}/config" 
  # safety net for non existent directories
  [ $? -gt 0 ] && exit 1
  # Create ALL the join blocks of the Vault Servers if a_vault_cnt is greater than 1
  >all_vault_servers.txt
  for i2_cnt in $(seq $a_vaultcnt) ; do
    icorrection=$(( $i2_cnt - 1 ))  
    port_i=$(( $icorrection * 10   + 8200 ))
    cat << EOFT1  > t_addon.txt 
        retry_join {
          leader_api_addr = "http://127.0.0.1:${port_i}"
        }
EOFT1
  [[ $i_cnt -gt 1 ]] && cat t_addon.txt >>all_vault_servers.txt
done

# Create transit seal block with the 127.0.0.1:8200 hardcoded for vault_1
cat << EOFT3 > t_addon.txt
seal "transit" {
   address            = "http://127.0.0.1:8200"
   disable_renewal    = "false"

   key_name           = "unseal_key"
   mount_path         = "transit/"
}
EOFT3

  rm -f config_?.hcl 2>/dev/null 

  # Create each Vault server config file
  for i_cnt in $(seq 2 $a_vaultcnt) ; do
    icorrection=$(( $i_cnt - 1 ))  
    echo "Create final Vault server ${a_working_dir}/config/config_${i_cnt}.hcl"
    export port_i=$(( $icorrection * 10   + 8200 ))
    export port_iha=$(( $icorrection * 10  + 8201 ))
    mkdir -p "${a_workingdir}/data/vault_raft_${i_cnt}"
    cat << EOFT2 >  config_${i_cnt}.hcl 
pid_file      = "${a_workingdir}/logs/vault-${i_cnt}.pid"
ui = true
api_addr      = "http://127.0.0.1:${port_i}"
cluster_addr  = "http://127.0.0.1:${port_iha}"

listener "tcp" {
  address = "0.0.0.0:${port_i}"
  tls_disable = 1
}

storage "raft" {
        path = "${a_workingdir}/data/vault_raft_${i_cnt}"
        node_id = "vault_${i_cnt}"

        retry_join {
          leader_api_addr = "http://127.0.0.1:8210"
        }
EOFT2
    [ -s all_vault_servers.txt ] && cat all_vault_servers.txt >> config_${i_cnt}.hcl
    echo '}' >> config_${i_cnt}.hcl
    cat t_addon.txt >> config_${i_cnt}.hcl
    [ $DEBUG -gt 0 ] && ( echo "Continue ===${FUNCNAME[*]}==== with the next Vault server?" ; read a_ans )
  done
  cat << EOFT4 > config_1.hcl
pid_file      = "${a_workingdir}/logs/vault-1.pid"
storage "inmem" {}

listener "tcp" {
   address = "127.0.0.1:8200"
   tls_disable = true
}

ui=true
disable_mlock = true
EOFT4
  return 0
}

function vault_cleanup()
{
  echo -ne "${hash_padding}Cleanup the vault logs and data files...\n"
  cd "${a_workingdir}/config"
  # safety net for non existent directories
  [ $? -eq 0 ] && rm recovery_key-vault_2 unseal_key-vault_1 unseal_operation_vault_1.txt t_addon.txt all_vault_servers.txt 2>/dev/null && find . -type f -name '*.hcl' -print -exec rm -rf -- {} \;
  cd "${a_workingdir}/data"
  if [ $? -eq 0 ] ; then
	 for tdir in $(ls) ; do
		 rm -rf -- "$tdir" && echo "rm $tdir" 
	 done;
  fi
  cd "${a_workingdir}/logs"
  if [ $? -eq 0 ] ; then
	 for tfile in $(ls vault* 2>/dev/null) ; do
		 rm -f -- "$tfile" && echo "rm $tfile" 
	 done;
  fi
  echo -ne "${hash_padding}Cleanup complete.${hash_padding}\n"
  return 0
}

function start_transit_vault()
{
  echo "$hash_padding===${FUNCNAME[*]}==== "
  cd ${a_workingdir}/config
  # safety net for non existent directories
  [ $? -gt 0 ] && exit 1
  export VAULT_ADDR="http://127.0.0.1:8200" 
  export VAULT_LICENSE_PATH="${a_workingdir}/config/license.hclic"
  vault server -log-level=trace -config=./config_1.hcl 1>/dev/null &
  echo 'Working on... '
  while : ; do
    echo -ne '\r - |'
    vault status 1>/dev/null 2>/dev/null
    if [ $? -eq 2 ] ; then
	    break 1
    else
	    echo -ne '\r - \ '; sleep 1
    fi
  done
  vault status
  #export INIT_RESPONSE=$(vault operator init -format=json -key-shares 1 -key-threshold 1 )
  export INIT_RESPONSE=$(vault operator init -format=json -key-shares 1 -key-threshold 1 2>/dev/null)
  export UNSEAL_KEY=$(echo "$INIT_RESPONSE" | jq -r .unseal_keys_b64[0])
  export VAULT_TOKEN=$(echo "$INIT_RESPONSE" | jq -r .root_token)

  echo "$UNSEAL_KEY" > unseal_key-vault_1
  echo "$VAULT_TOKEN" > root_token-vault_1

  vault operator unseal "$UNSEAL_KEY" > unseal_operation_vault_1.txt
  vault login "$VAULT_TOKEN"
  vault secrets enable transit
  vault write -f transit/keys/unseal_key
  echo "Successfully unsealed the First Vault Server used for Transit Key"
return 0
}

function start_vault()
{
  echo "$hash_padding===${FUNCNAME[*]}==== "
  cd "${a_workingdir}/config" || (echo "No configuration directoy!" ; return 1)
  # safety net for non existent directories
  [ $? -gt 0 ] && exit 1

 for i_cnt in $(seq 2 ${a_vaultcnt} ) ; do
  echo " Starting Vault Server $i_cnt..."
  #mkdir -p "${a_workingdir}/data/vault_${i_cnt}"
  local icorrection=$(( $i_cnt - 1 ))
  local port_i=$(( $icorrection * 10  + 8200 ))
  local port_iha=$(( $icorrection * 10  + 8201 ))
  export VAULT_ADDR="http://127.0.0.1:${port_i}" ; export ROOT_TOKEN=''
  export VAULT_LICENSE_PATH="${a_workingdir}/config/license.hclic"
  vault server -log-level=trace -config=./config_${i_cnt}.hcl 2>/dev/null 1>/dev/null &
  #vault server -log-level=trace -config=./config_${i_cnt}.hcl &
  set +x
  lretrys=1
  while [ $lretrys -lt $RETRYS ]  ; do
    vault status 1>/dev/null 
    [ $? -eq 2 ] && lretrys=98 || sleep 1
    lretrys=$(( $lretrys + 1 ))
  done
  if [ $lretrys -eq 99 ] ; then
     vault status
  else
     echo "Failed to start the Vault Server vault-${i_cnt}"
     return 1
  fi

  [ $DEBUG -gt 0 ] && ( echo "Continue ===${FUNCNAME[*]}==== with the next Vault server?" ; read a_ans )
done
  return 0
}

function validate_vault()
{
  echo "$hash_padding===${FUNCNAME[*]}==== "
  cd ${a_workingdir}/config
  # safety net for non existent directories
  [ $? -gt 0 ] && exit 1
  for i_cnt in $(seq 2 ${a_vaultcnt}) ; do
     local icorrection=$(( $i_cnt - 1 ))
     local port_i=$(( $icorrection * 10  + 8200 ))
     export VAULT_ADDR="http://127.0.0.1:${port_i}" 
     export INIT_RESPONSE=$(cat "root_token-vault_${i_cnt}")
     #export RECOVERY_KEY=$(echo "$INIT_RESPONSE" | jq -r .unseal_keys_b64[0])
     export VAULT_TOKEN=$(echo "$INIT_RESPONSE" )
     echo "${hash_padding}Testing the Vault Server Vault-${i_cnt} using Transit Key"
     vault login "$VAULT_TOKEN"
     vault secrets enable -path=kv kv-v2
     vault kv put kv/apikey webapp=testvalueinthefield
     vault secrets list
     vault kv get kv/apikey
     #vault secrets disable kv
     vault operator raft list-peers
     echo "${hash_padding} Done testing"
     [ $DEBUG -gt 0 ] && ( echo "Continue ===${FUNCNAME[*]}==== with the next Vault server?" ; read a_ans )
  done
  cd ${a_workingdir}
  return 0
}

function unseal_vault()
{
  echo "$hash_padding===${FUNCNAME[*]}==== "
  cd ${a_workingdir}/config
  # safety net for non existent directories
  [ $? -gt 0 ] && exit 1
  local i_node=2 ; local icorrection=$(( $i_node - 1)) 
  local port_i=$(( $icorrection * 10  + 8200 ))
  export VAULT_ADDR="http://127.0.0.1:${port_i}" 
  export INIT_RESPONSE=$(vault operator init -format=json -recovery-shares 1 -recovery-threshold 1 2>/dev/null )
  export RECOVERY_KEY=$(echo "$INIT_RESPONSE" | jq -r .unseal_keys_b64[0])
  export VAULT_TOKEN=$(echo "$INIT_RESPONSE" | jq -r .root_token)
  echo "$RECOVERY_KEY" > "recovery_key-vault_${i_node}"
  echo "$VAULT_TOKEN" > "root_token-vault_${i_node}"
  echo "${hash_padding}Unsealed the Vault Server Vault-${i_node} using Transit Key"
  for i_cnt in $(seq 3 ${a_vaultcnt}) ; do
     #cp "root_token-vault_${i_node}" "root_token-vault_${i_cnt}"
     ln -s  "root_token-vault_${i_node}" "root_token-vault_${i_cnt}"
     [ $DEBUG -gt 0 ] && ( echo "Continue ===${FUNCNAME[*]}==== with the next Vault server Vault-${i_cnt}?" ; read a_ans )
  done
  sleep 15
  [ $DEBUG -gt 0 ] && vault status
  return 0
}

function vault_ha_init()
{
  echo "${hash_padding}===${FUNCNAME[*]}==== "
  cd ${a_workingdir}/config
  # safety net for non existent directories
  [ $? -gt 0 ] && exit 1
  for i_cnt in $(seq 3 ${a_vaultcnt}) ; do
     local icorrection=$(( $i_cnt - 1 ))
     local port_i=$(( $icorrection * 10  + 8200 ))
     export VAULT_ADDR="http://127.0.0.1:${port_i}" 
     export VAULT_JOIN_ADDR="http://127.0.0.1:8210}" 
     export INIT_RESPONSE=$(cat "root_token-vault_${i_cnt}")
     export VAULT_TOKEN=$(echo "$INIT_RESPONSE")
     echo "Vault Server vault-${i_cnt} Joining the Vault Server Vault-${icorrection}"
     vault login "$VAULT_TOKEN"
     vault operator raft list-peers
     #vault operator raft join "$VAULT_JOIN_ADDR"
     echo "${hash_padding}Cluster formation done."
  done
  cd ${a_workingdir}
  return 0
}

function stop_vault()
{
  cd ${a_workingdir}/logs
  # safety net for non existent directories
  [ $? -gt 0 ] && exit 1
  # Executing stop in reverse order

  for i_cnt in $(seq ${a_vaultcnt} 1) ; do
     local icorrection=$(( $i_cnt - 1 ))
     local port_i=$(( $icorrection * 10  + 8200 ))
     ##    vault operator raft list-peers
     ##    vault operator raft remove-peer

     local list_pids=$(ps -fe|grep vault|grep hcl|grep -e '-config=./config_'|awk '{print $2," "}')
     pidtokill=$(cat ${a_workingdir}/logs/vault-${i_cnt}.pid 2>/dev/null)
     for pidtocheck in  $(echo  ${list_pids}) ; do
	     if [[ $pidtokill -eq $pidtocheck ]] ; then
		echo "Found the Vault-${i_cnt} PID $pidtokill into ${list_pids}"
		[ $pidtokill -gt 100 ] && kill -9  $pidtokill && sleep 1
		break 1
	     fi
     done
     echo "${hash_padding} Cluster formation updated."
     [ $DEBUG -gt 0 ] && ( echo "Continue with the next Vault server?" ; read a_ans )
  done
  return 0
}


### MAIN BODY
[ $DEBUG -gt 0 ] && ( echo -ne "${hash_padding}\nUsing: ${a_workingdir} as base ? (<Enter> for default path)"  && read a_ans )
if [ -d "${a_workingdir}/data" ] ; then
  stop_vault
  echo "Directory already present. Cleanup and re-execute the script."
  echo "Execute: 
  cd ${a_maindir} && rm -rf ${a_basedir}/data
  cd ${a_maindir} && rm -rf ${a_basedir}/logs"
  exit 1
else
  echo "Using ${a_maindir} and ${a_basedir}"
  cd "${a_maindir}" 
  mkdir -p "${a_workingdir}/logs"
  mkdir -p "${a_workingdir}/config"
  mkdir -p "${a_workingdir}/data"
  chmod 0755 "${a_workingdir}/data"
fi

create_vault_conf 
start_transit_vault
start_vault
unseal_vault
vault_ha_init
validate_vault

if [ $DEBUG -gt 0 ] ; then
   echo -ne "${hash_padding}\nTesting and validation OK? (<Enter> for ending thje script)"  && read a_ans 
else
   echo -ne "${hash_padding} Vault(Transit) TOKEN is: $(cat ${a_wrokingdir}/config/root_token-vault_1) \n"
   echo -ne "${hash_padding} HA Vault(NODE) TOKEN is: $(cat ${a_wrokingdir}/config/root_token-vault_2) \n"
   echo -ne "${hash_padding} \nLeaving the servers running for $TESTWINDOW";sleep ${TESTWINDOW}
fi
echo -ne  "${hash_padding}Done.\n"
stop_vault
# No need to execute the global kill of all Vault servers as a new function is cleaning the Vault servers
# based on the PIDs recorded into 'pid file' during startup.
#killall vault

vault_cleanup

