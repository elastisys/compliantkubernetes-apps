## CRD management

* CRDs are vendored in this folder and deployed by ansible in the bootstrap-crds play.
    * CRD deployment shall be disabled in ck8s helm charts/operators that contain CRDs.

* Mapping of CRDs to clusters
    * The files crds-sc|wc.txt decides which CRDs that are deployed to the service and workload clusters respectively.

* Adding CRDs or changing CRD version
    * To add a vendor CRD, modify get-vendor-crds.sh and add a line to download the CRD. Note the naming convention of vendored CRDs, no version number is to be included.
        * Add the new CRDs in a folder that is named after the application that is using/controlling the CRDs
        * Also add the CRD to crds-sc|wc.txt as required
    * To change CRD version, modify the entry for the CRD in get-vendor-crds.sh to reflect the desired version. Note that this needs to be done manually when upgrading a chart.
