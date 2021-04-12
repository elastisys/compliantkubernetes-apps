### Restore Harbor
With the script `restore-harbor.sh` you can restore the database in Harbor from a backup in S3.

Before restoring the database, make sure that Harbor is installed. It can be installed normally.

In order to run the restore script you need the aws client and the postgres client installed:
```bash
curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "awscli-bundle.zip"
unzip awscli-bundle.zip
sudo ./awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws
sudo apt install postgresql-client-10
sudo apt install postgresql-client-common
```
Set these variables for the restore-script:
```bash
export CK8S_CONFIG_PATH=<your config path>
export S3_BUCKET=$(yq read "${CK8S_CONFIG_PATH}/sc-config.yaml" objectStorage.buckets.harbor)
export S3_REGION_ENDPOINT=$(yq read "${CK8S_CONFIG_PATH}/sc-config.yaml" objectStorage.s3.regionEndpoint)
export AWS_ACCESS_KEY_ID=$(sops -d "${CK8S_CONFIG_PATH}/secrets.yaml" | yq read - objectStorage.s3.accessKey)
export AWS_SECRET_ACCESS_KEY=$(sops -d "${CK8S_CONFIG_PATH}/secrets.yaml" | yq read - objectStorage.s3.secretKey)
```
While restoring we need to stop all harbor pods except for the database. Then restart them after the restoration.
Run these commands to stop the pods, restore the database, and restart the pods:
```bash
./bin/ck8s ops kubectl sc scale deployment --replicas 0 -n harbor --all
./bin/ck8s ops kubectl sc port-forward -n harbor harbor-harbor-database-0 5432:5432 &
PORT_FORWARD_PID=$!
./restore-harbor.sh
kill $PORT_FORWARD_PID
./bin/ck8s ops kubectl sc scale deployment --replicas 1 -n harbor --all
