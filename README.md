[![license](http://img.shields.io/badge/license-apache_2.0-red.svg?style=flat)](https://github.com/florintp-onboarding/vault_cluster_raft_localhost/blob/main/LICENSE)


# Running a Vault cluster with Raft storage backend on localhost

The repository is used for creating a test Vault+Raft Integrated storage playground.
The script is written in Bash and was successfully tested on MAC (Intel and M1).


# Prerequisites
Install the latest version of vault and bash for your distribution.
As example for MAC, using brew:
```
brew install vault
brew install bash
brew install git
brew install gh
```

# Running the Vault HA Cluster with Raft integrated storage
The following block actions are executed by the functions from the script:
 - Validating the environment directory.
 - Creating the transit Vault server as (vault-1).
 - Start and unseal the first Vault Server (vault-i) used as transit for store the unsealing transit key.
 - Create the unseal transit key.
 - Create the Vault configuration files, in a dynamic way, cluster nodes (n-1) (./vault/config/vault-1 ./vault/config/vault-2 ...).
 - For example, by specifying the variable a_vaultcnt=6, the number of Vault servers created is 6: one transit "in memory" Vault server and 5 Vault servers running in a HA Cluster with Raft as storage backed.
 - Recover the shared key from initialization from transit Vault (vault-1) and create a temporary store of VAULT_TOKEN (only for testing purposes).
 - Enable a secret engine type KV in the path kv of version kv-v2.
 - Store a secret into apikey with field webapp=testvalueinthefield.
 - Stop every Vault server (vault-n, vault-(n-1),..., vault-2, vault-1).
 - Clean-up the files and folders: ./vault/config ./vault/data ./vault/logs
 

# How to create the Vault HA Cluster
- Clone the current repository or only the current script create_cluster.sh
```
git clone https://github.com/florintp-onboarding/vault_cluster_raft_localhost
```
or
```
gh repo clone florintp-onboarding/vault_cluster_raft_localhost
```
- If an enterprise binary is used, then the license file should be copied into:
"./vault/config/license.hclic"
- Adapt the number of retries for actions by modifying the variable
(default RETRY=6)
RETRYS
- Choose the running mode by modifying number value from the initilization variable DEBUG 
(default DEBUG=0)
- For any non-zero value DEBUG the script will run in interactive mode and will prompt for actions.
- While runing in non-interactive mode (DEBUG="0") the variable TESTWINDOW will configure the wait time for keeping the Vault Servers running. If the script is running in interactive mode (debug mode), then this variable is ingnored. 
- Execute the script as
```
cd vault_raft_localhost
bash create_cluster.sh
```
- Open another terminal console on the host and 
and observe the root_token files needed to login to UI.
- Open a browser and login to Vault (transit) Server at http://localhost:8200
(* using the token from vault/config/root_token-vault_1 )
- For login to the Vault cluster you may use any of the cluster nodes (port= 10*n + 8200)
- For example, for UI access on node 2 you may use the address http://localhost:8210
- For UI access on node 3 you may use the address http://localhost:8220
- For UI access on node 4 you may use the address http://localhost:8230
(** by using the VAULT_TOKEN from vault/config/root_token-vault_2 )


# Additional facts:
- If the vault directory is present then a clean-up is needed.
In this scenario, the script is singaling the vault directory presence and prints the delete instructions and exit.
This is expected behavior on multiple executions of the script.

- For test purposes, the variable DEBUG may be set to a number value greater than "0".
This will allow the validation and the test scenarios in a step-by-step fashion.
- While running in DEBUG mode the script will wait for confirmation for every block action.

# One successful execution (waiting for test window to finish) looks like:
```
vault_raft_localhost $ tree
.
├── README.md
├── create_cluster.sh
└── vault
    ├── config
    │   ├── all_vault_servers.txt
    │   ├── config_1.hcl
    │   ├── config_2.hcl
    │   ├── config_3.hcl
    │   ├── config_4.hcl
    │   ├── config_5.hcl
    │   ├── config_6.hcl
    │   ├── root_token-vault_1
    │   ├── t_addon.txt
    │   ├── unseal_key-vault_1
    │   └── unseal_operation_vault_1.txt
    ├── data
    │   ├── vault_raft_2
    │   │   ├── raft
    │   │   │   ├── raft.db
    │   │   │   └── snapshots
    │   │   └── vault.db
    │   ├── vault_raft_3
    │   │   ├── raft
    │   │   │   ├── raft.db
    │   │   │   └── snapshots
    │   │   └── vault.db
    │   ├── vault_raft_4
    │   │   ├── raft
    │   │   │   ├── raft.db
    │   │   │   └── snapshots
    │   │   └── vault.db
    │   ├── vault_raft_5
    │   │   ├── raft
    │   │   │   ├── raft.db
    │   │   │   └── snapshots
    │   │   └── vault.db
    │   └── vault_raft_6
    │       ├── raft
    │       │   ├── raft.db
    │       │   └── snapshots
    │       └── vault.db
    └── logs
        ├── vault-1.pid
        ├── vault-2.pid
        ├── vault-3.pid
        ├── vault-4.pid
        ├── vault-5.pid
        └── vault-6.pid

19 directories, 29 files
```
