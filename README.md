# vault_raft_localhost

The repository is used for creating a test Vault+Raft Integrated storage playground.
The script is written in Bash and was successfully tested on MAC (Intel and M1).


# Prerequisites
Install the latest version of vault and bash for your distribution.
As example for MAC, using brew:
```
brew install vault
brew install bash
```

# Running the Vault HA Cluster with Raft integrated storage
The following block actions are executed by the functions from the script:
 - validating the environment
 - creating the transit Vault server
 - start and unseal the first Vault Server used as transit for unsealing key
 - Create the unseal transit key
 - Create Vault configuration files,in a dynamic way, cluster nodes (n-1) by specifying the variable
a_vaultcnt=6
(default if 6 Vault servers, one transit "in memory" server and 5 Vault servers running in a HA Cluster and having as Raft as storage backed).
 - Recover the shared key from initialization from transit Vaul and create a temporary store of VAULT_TOKEN (only for testing purposes)
 - Enable a secret engine type KV in the path kv of version kv-v2
 - Store a secret into apikey with field webapp=testvalueinthefield.
 

# How to create the Vault HA Cluster
- Clone the current repository or only the current script create_cluster.sh
```
git clone github.com/FlorinTP/vault_raft_localhost
```
- If an enterprise binery is used then the license file should be copied into:
"./vault/config/license.hclic"
- Adapt the number of retries for actions by modifying the variable
(default RETRY=6)
RETRYS
- Adapt the DEBUG mode by modifying the variable
(default DEBUG=0)
- Adapt the TEST time for which the Servers should be up and running.
- Execute the script as
```
bash create_cluster.sh
```
- Open another terminal console on the host and 
and oobserve the root_token files needed to login to UI.
- Open a browser and login to Vault (transit) Server at http://localhost:8200
by using the token from vault/config/root_token-vault_1
- For login to the Vault cluster you may use any of the cluster nodes (port= 10*n + 8200)
for example, for UI access on node 2 you may use the address http://localhost:8210
for UI access on node 3 you may use the address http://localhost:8220
for UI access on node 4 you may use the address http://localhost:8230
with the VAULT_TOKEN from root_token-vault_2


# Additional facts:
- If the vault directory is present then a cleanu-up is needed.
In this scenario the script is singaling the vault directory and echo the  delete instructions and exit.
This is expected behavior on multiple executions.

- For test purpose, the variable DEBUG may be set to a number value greater than "0".
This will allow the validation and the test scenarios in a step-by-step fashion.
- While running in DEBUG mode the script will wait for confirmation for every block action.

# One successful execution (waiting for test window to finish looks likei):
```
tree
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
