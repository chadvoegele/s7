# S7

## Description
Stable, Secure, Saver Sync to Simple Storage Service (S3)

Sync files to S3 using client-side encryption with configurable cold tier options.

## Example Usage
```
s7 sync file://root enc+s3://bucket/prefix
s7 sync enc+s3://bucket/prefix file://root
```

## Example Workflow
```
$ mkdir -p data/{in,out}
$ echo "data" > data/in/file.txt
$ s7 --secrets=<(get_secrets) sync file://data/in enc+s3://bucket/backups
$ aws ls s3://bucket/backups/
2020-07-10 20:11:27         38 ATSbNROIKQQmlm3XYhCK3msDfV3X8eQ1X8Wi+liF_6JPgaKMty6lzEI=
$ s7 --secrets=<(get_secrets) restore enc+s3://bucket/backups
$ s7 --secrets=<(get_secrets) sync enc+s3://bucket/backups file://data/out
$ cat data/out/file.txt
data
```


## Pricing
For 1 TB of data, the storage costs using S3 Glacier Deep Archive are around $12/year. Retrieving the data using bulk retrieval costs $3.
