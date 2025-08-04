import argparse
from datetime import datetime, timezone, timedelta
import os
import random
import string
import sys
import logging

import boto3
from botocore.client import Config, BaseClient

def get_s3_client(signature_version: str) -> BaseClient:
    """
    Creates and returns a boto3 S3 client.

    The client is configured to read credentials, region, and endpoint URL
    from standard environment variables.

    :param signature_version: The default signature version to use ('s3' or 's3v4').
                              This can be overridden by the AWS_SIGNATURE_VERSION
                              environment variable.
    """
    return boto3.client(
        's3',
        config=Config(signature_version=os.environ.get('AWS_SIGNATURE_VERSION', signature_version)),
        region_name=os.environ.get('AWS_DEFAULT_REGION', 'us-east-1')
    )

def generate_random_key() -> str:
    """Generates a random key for the S3 object."""
    random_suffix = ''.join(random.choices(string.ascii_lowercase + string.digits, k=8))
    return f"bigfile-{random_suffix}.bin"

def handle_trigger(s3: BaseClient, args: argparse.Namespace) -> None:
    """
    Handles the 'trigger' subcommand to create an incomplete multipart upload.
    This is intended to be used for testing the cleanup subcommand.

    :param s3: The S3 client to use.
    :param args: The command-line arguments.
    """
    bucket = args.bucket_name
    key = args.key if args.key else generate_random_key()

    logging.info(f"Initiating multipart upload for key '{key}' in bucket '{bucket}'...")

    try:
        # Step 1: Initiate multipart upload
        resp = s3.create_multipart_upload(Bucket=bucket, Key=key)
        upload_id = resp['UploadId']
        logging.info(f"Started multipart upload: {upload_id}")

        # Step 2: Upload one part to create an orphaned data part.
        logging.info("Uploading one 5MB part...")
        with open('/dev/zero', 'rb') as f:
            data = f.read(5 * 1024 * 1024)  # 5MB
            s3.upload_part(Bucket=bucket, Key=key, PartNumber=1, UploadId=upload_id, Body=data)
        logging.info("Part uploaded.")

        # Step 3: Stop here — we do not call complete_multipart_upload.
        # The upload is now "incomplete".
        logging.info("\nIncomplete multipart upload created successfully.")
        logging.info(f"  Bucket: {bucket}")
        logging.info(f"  Key: {key}")
        logging.info(f"  Upload ID: {upload_id}")

    except Exception as e:
        logging.critical(f"An error occurred during trigger: {e}", exc_info=True)
        sys.exit(1)

def handle_cleanup(s3: BaseClient, args: argparse.Namespace) -> None:
    """
    Handles the 'cleanup' subcommand to abort old incomplete multipart uploads.
    """
    aborted_count = cleanup_incomplete_uploads(s3, args.bucket_name, args.max_age)
    logging.info(f"Done. Aborted {aborted_count} old incomplete multipart uploads.")

def cleanup_incomplete_uploads(s3: BaseClient, bucket: str, max_age: int) -> int:
    """
    Finds and aborts incomplete multipart uploads older than a specified number of days.

    :param s3: The S3 client to use.
    :param bucket: The name of the bucket to clean up.
    :param max_age: The age threshold in days for incomplete uploads.
    :return: The number of aborted uploads.
    """
    cutoff_date = datetime.now(timezone.utc) - timedelta(days=max_age)

    logging.info(f"Searching for incomplete multipart uploads in bucket '{bucket}' older than {max_age} days (before {cutoff_date.isoformat()})...")

    aborted_count = 0
    try:
        paginator = s3.get_paginator('list_multipart_uploads')
        pages = paginator.paginate(Bucket=bucket)

        for page in pages:
            if "Uploads" in page:
                for upload in page['Uploads']:
                    if upload['Initiated'] < cutoff_date:
                        logging.info(f"Aborting old incomplete upload for key '{upload['Key']}' (UploadId: {upload['UploadId']}), initiated on {upload['Initiated'].isoformat()}")
                        try:
                            s3.abort_multipart_upload(Bucket=bucket, Key=upload['Key'], UploadId=upload['UploadId'])
                            aborted_count += 1
                        except Exception:
                            logging.error(f"Failed to abort upload for key '{upload['Key']}'", exc_info=True)
                            sys.exit(1)

    except Exception:
        logging.critical("An error occurred while listing multipart uploads.", exc_info=True)
        sys.exit(1)

    return aborted_count

def parse_args() -> argparse.Namespace:
    """Parse command-line arguments with subcommands."""
    parser = argparse.ArgumentParser(
        description="Manage S3 multipart uploads for testing and cleanup."
    )
    subparsers = parser.add_subparsers(dest='command', required=True, help='Sub-command to execute')

    # --- Trigger Subcommand Parser ---
    parser_trigger = subparsers.add_parser(
        'trigger',
        help='Trigger an incomplete multipart upload.'
    )
    parser_trigger.add_argument(
        '--bucket-name',
        required=True,
        help='The S3 bucket to create the incomplete upload in.'
    )
    parser_trigger.add_argument(
        '--key',
        help='The key for the object to upload. Defaults to a random name.'
    )
    parser_trigger.set_defaults(func=handle_trigger)

    # --- Cleanup Subcommand Parser ---
    parser_cleanup = subparsers.add_parser(
        'cleanup',
        help='Clean up old incomplete multipart uploads.'
    )
    parser_cleanup.add_argument(
        '--bucket-name',
        required=True,
        help='The S3 bucket to clean up.'
    )
    parser_cleanup.add_argument(
        '--max-age',
        type=int,
        default=7,
        help='Age threshold in days for incomplete uploads to be cleaned up.'
    )
    parser_cleanup.set_defaults(func=handle_cleanup)

    return parser.parse_args()

def main() -> None:
    """Main entry point."""
    logging.basicConfig(
        level=os.environ.get("LOG_LEVEL", "INFO").upper(),
        format='%(asctime)s - %(levelname)s - %(message)s'
    )

    args = parse_args()

    # For Swift compatibility
    if args.command == 'trigger':
        s3 = get_s3_client(signature_version='s3')
    else:
        s3 = get_s3_client(signature_version='s3v4')

    args.func(s3, args)

if __name__ == "__main__":
    main()
