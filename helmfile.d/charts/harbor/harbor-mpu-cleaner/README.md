# MPU (MultipartUpload) Cleaner

Chart for wrapping a Kubernetes cronjob containing a script which cleans up stale multipartUploads.

Requires the image defined under `images/python-boto3`.

The script can be tested using docker:

```bash
# Create "unfinished" multipartupload:
docker run \
    -it \
    -e AWS_ACCESS_KEY_ID \
    -e AWS_SECRET_ACCESS_KEY \
    -e AWS_ENDPOINT_URL \
    -v ./scripts/mpu-tool.py:/mpu-tool.py \
    --name mpu python-boto3:0.1.1 \
    /mpu-tool.py trigger --bucket-name yourbucket-harbor

# Cleanup:
docker run \
    -it \
    -e AWS_ACCESS_KEY_ID \
    -e AWS_SECRET_ACCESS_KEY \
    -e AWS_ENDPOINT_URL \
    -v ./scripts/mpu-tool.py:/mpu-tool.py \
    --name mpu python-boto3:0.1.1 \
    /mpu-tool.py cleanup --bucket-name yourbucket-harbor --max-age 0
```
