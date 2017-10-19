# corrective_actions
Just a collection of corrective actions that can be deployed on OEM. 
I am trying to write all corrective actions on a single script since I do not have a depot.

purge-u01 - Job to clean up clutters in u01. For 10G, cleans up the trace files and alerts logs. 11G+ Uses the 10G plus clean up using adrci. 
