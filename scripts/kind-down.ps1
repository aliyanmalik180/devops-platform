# Deletes the whole local cluster (and everything in it). Free to recreate any time.
. "$PSScriptRoot\common.ps1"
Test-Prereqs @("kind")
Invoke-Step "Deleting kind cluster '$ClusterName'" { kind delete cluster --name $ClusterName }
