#!/usr/bin/env bash
TEST_DIR="/tmp/s7_tests.XXXXXXX"

function main() {
  run_test test_add
  run_test test_update_same_size
  run_test test_update_different_size
  run_test test_deletion
  run_test test_multiple_files
  run_test test_encryption_limit
  [[ -n $S7_LONG_TESTS ]] && run_test test_large_file

  if [[ -n "$AWS_ACCESS_KEY_ID" && -n "$AWS_SECRET_ACCESS_KEY" && -n "$AWS_DEFAULT_REGION" ]]
  then
    run_s3_test test_s3
    run_s3_test test_s3_multiple_prefixes
    [[ -n $S7_LONG_TESTS ]] && run_s3_test test_s3_list_pages
    [[ -n $S7_LONG_TESTS ]] && run_s3_test test_s3_restore
    [[ -n $S7_LONG_TESTS ]] && run_s3_test test_s3_restore_after_restore
    [[ -n $S7_LONG_TESTS ]] && run_s3_test test_s3_increase_partsize
  else
    echo "To run S3 tests, set the environment variables AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_DEFAULT_REGION"
  fi
}

function run_test() {
  test_function="$1"
  test_dir="$TEST_DIR"
  temp_dir=$(make_directory "$test_dir")
  echo "Starting test $test_function at $temp_dir"
  trap 'rm -r $temp_dir && echo "Test $test_function failed!"' EXIT
  start_seconds=$SECONDS
  eval "$test_function" "$temp_dir"
  end_seconds=$SECONDS
  elapsed_seconds=$(( end_seconds - start_seconds ))
  echo "Passed test $test_function ($elapsed_seconds s)"
  clean_directory "$temp_dir"
  trap - EXIT
}

function run_s3_test() {
  test_function="$1"
  test_dir="$TEST_DIR"
  bucket_name=$(make_bucket)
  temp_dir=$(make_directory "$test_dir")
  echo "Starting s3 test $test_function at $temp_dir and bucket s3://${bucket_name}"
  trap 'rm -r $temp_dir && remove_bucket $bucket_name && echo "Test $test_function failed!"' EXIT
  start_seconds=$SECONDS
  eval "$test_function" "$temp_dir" "$bucket_name"
  end_seconds=$SECONDS
  elapsed_seconds=$(( end_seconds - start_seconds ))
  echo "Passed test $test_function ($elapsed_seconds s)"
  clean_directory "$temp_dir"
  remove_bucket "$bucket_name"
  trap - EXIT
}

function test_add() {
  test_dir="$1"
  mkdir -p "$test_dir"/data/{in,enc,out}
  echo "test data" > "$test_dir/data/in/test.txt"
  in_sync=$(s7 sync file://"$test_dir/data/in" enc+file://"$test_dir/data/enc")
  assert_in "$in_sync" "1 file(s) added"
  out_sync=$(s7 sync enc+file://"$test_dir/data/enc" file://"$test_dir/data/out")
  assert_in "$out_sync" "1 file(s) added"
  diff -r "$test_dir/data/in" "$test_dir/data/out"
  diff_exit="$?"
  assert_eq "$diff_exit" "0"
}

function test_update_same_size() {
  test_dir="$1"
  mkdir -p "$test_dir"/data/{in,enc,out}
  echo "test data" > "$test_dir/data/in/test.txt"
  s7 sync file://"$test_dir/data/in" enc+file://"$test_dir/data/enc" > /dev/null
  s7 sync enc+file://"$test_dir/data/enc" file://"$test_dir/data/out" > /dev/null
  echo "Test data" > "$test_dir/data/in/test.txt"
  in_sync=$(s7 sync file://"$test_dir/data/in" enc+file://"$test_dir/data/enc")
  out_sync=$(s7 sync enc+file://"$test_dir/data/enc" file://"$test_dir/data/out")
  assert_in "$in_sync" "1 file(s) updated"
  assert_in "$out_sync" "1 file(s) updated"
  diff -r "$test_dir/data/in" "$test_dir/data/out"
  diff_exit="$?"
  assert_eq "$diff_exit" "0"
}

function test_update_different_size() {
  test_dir="$1"
  mkdir -p "$test_dir"/data/{in,enc,out}
  echo "test data" > "$test_dir/data/in/test.txt"
  s7 sync file://"$test_dir/data/in" enc+file://"$test_dir/data/enc" > /dev/null
  s7 sync enc+file://"$test_dir/data/enc" file://"$test_dir/data/out" > /dev/null
  printf "test data\ntest data" > "$test_dir/data/in/test.txt"
  in_sync=$(s7 sync file://"$test_dir/data/in" enc+file://"$test_dir/data/enc")
  out_sync=$(s7 sync enc+file://"$test_dir/data/enc" file://"$test_dir/data/out")
  assert_in "$in_sync" "1 file(s) updated"
  assert_in "$out_sync" "1 file(s) updated"
  diff -r "$test_dir/data/in" "$test_dir/data/out"
  diff_exit="$?"
  assert_eq "$diff_exit" "0"
}

function test_deletion() {
  test_dir="$1"
  mkdir -p "$test_dir"/data/{in,enc,out}
  echo "test data" > "$test_dir/data/in/test.txt"
  s7 sync file://"$test_dir/data/in" enc+file://"$test_dir/data/enc" > /dev/null
  s7 sync enc+file://"$test_dir/data/enc" file://"$test_dir/data/out" > /dev/null
  rm "$test_dir/data/in/test.txt"
  in_sync=$(s7 sync file://"$test_dir/data/in" enc+file://"$test_dir/data/enc")
  out_sync=$(s7 sync enc+file://"$test_dir/data/enc" file://"$test_dir/data/out")
  assert_in "$in_sync" "1 file(s) deleted"
  assert_in "$out_sync" "1 file(s) deleted"
  diff -r "$test_dir/data/in" "$test_dir/data/out"
  diff_exit="$?"
  assert_eq "$diff_exit" "0"
}

function test_multiple_files() {
  test_dir="$1"
  mkdir -p "$test_dir"/data/{in,enc,out}
  mkdir -p "$test_dir"/data/in/{prefix1,prefix2}
  echo "test data" > "$test_dir/data/in/test.txt"
  echo "test data" > "$test_dir/data/in/prefix1/test.txt"
  echo "test data" > "$test_dir/data/in/prefix2/test.txt"
  in_sync=$(s7 sync file://"$test_dir/data/in" enc+file://"$test_dir/data/enc")
  out_sync=$(s7 sync enc+file://"$test_dir/data/enc" file://"$test_dir/data/out")
  assert_in "$in_sync" "3 file(s) added"
  assert_in "$out_sync" "3 file(s) added"
  diff -r "$test_dir/data/in" "$test_dir/data/out"
  diff_exit="$?"
  assert_eq "$diff_exit" "0"
}

function test_large_file() {
  test_dir="$1"
  mkdir -p "$test_dir"/data/{in,enc,out}
  dd bs=1M count=1000 if=/dev/random of="$test_dir/data/in/out.data" status=none
  in_sync=$(s7 sync file://"$test_dir/data/in" enc+file://"$test_dir/data/enc")
  out_sync=$(s7 sync enc+file://"$test_dir/data/enc" file://"$test_dir/data/out")
  assert_in "$in_sync" "1 file(s) added"
  assert_in "$out_sync" "1 file(s) added"
  diff -r "$test_dir/data/in" "$test_dir/data/out"
  diff_exit="$?"
  assert_eq "$diff_exit" "0"
}

function test_encryption_limit() {
  test_dir="$1"
  mkdir -p "$test_dir"/data/{in,enc}
  fallocate -l 70G "${test_dir}/data/in/data.img"
  in_sync=$(s7 sync file://"$test_dir/data/in" enc+file://"$test_dir/data/enc")
  assert_in "$in_sync" "Skipping"
}

function test_s3() {
  test_dir="$1"
  bucket_name="$2"
  mkdir -p "$test_dir"/data/{in,out}
  echo "test data" > "$test_dir/data/in/test.txt"
  in_sync=$(aws_s7 sync --storage-class=STANDARD file://"$test_dir/data/in" enc+s3://${bucket_name}/prefix)
  assert_in "$in_sync" "1 file(s) added"
  out_sync=$(aws_s7 sync enc+s3://${bucket_name}/prefix file://"$test_dir/data/out")
  assert_in "$out_sync" "1 file(s) added"
  diff -r "$test_dir/data/in" "$test_dir/data/out"
  diff_exit="$?"
  assert_eq "$diff_exit" "0"

  # Clear bucket
  rm "$test_dir/data/in/test.txt"
  aws_s7 sync file://"$test_dir/data/in" enc+s3://${bucket_name}/prefix > /dev/null
}

function test_s3_multiple_prefixes() {
  test_dir="$1"
  bucket_name="$2"
  mkdir -p "$test_dir"/data/{in1,in2,out1,out2}
  echo "test data" > "$test_dir/data/in1/test.txt"
  echo "test data" > "$test_dir/data/in2/test.txt"

  in1_sync=$(aws_s7 sync --storage-class=STANDARD file://"$test_dir/data/in1" enc+s3://${bucket_name}/prefix1)
  assert_in "$in1_sync" "1 file(s) added"
  in2_sync=$(aws_s7 sync --storage-class=STANDARD file://"$test_dir/data/in2" enc+s3://${bucket_name}/prefix2)
  assert_in "$in2_sync" "1 file(s) added"

  out1_sync=$(aws_s7 sync enc+s3://${bucket_name}/prefix1 file://"$test_dir/data/out1")
  assert_in "$out1_sync" "1 file(s) added"
  out2_sync=$(aws_s7 sync enc+s3://${bucket_name}/prefix2 file://"$test_dir/data/out2")
  assert_in "$out2_sync" "1 file(s) added"

  diff -r "$test_dir/data/in1" "$test_dir/data/out1"
  diff_exit="$?"
  assert_eq "$diff_exit" "0"

  diff -r "$test_dir/data/in2" "$test_dir/data/out2"
  diff_exit="$?"
  assert_eq "$diff_exit" "0"

  # Clear bucket
  rm "$test_dir/data/in1/test.txt"
  aws_s7 sync file://"$test_dir/data/in1" enc+s3://${bucket_name}/prefix1 > /dev/null

  rm "$test_dir/data/in2/test.txt"
  aws_s7 sync file://"$test_dir/data/in2" enc+s3://${bucket_name}/prefix2 > /dev/null
}

function test_s3_list_pages() {
  test_dir="$1"
  bucket_name="$2"
  mkdir -p "$test_dir"/data/{in,out}
  for i in $(seq 1 1 1100)
  do
    echo "test data" > "$test_dir/data/in/test$i.txt"
  done
  in_sync=$(aws_s7 sync --storage-class=STANDARD file://"$test_dir/data/in" enc+s3://${bucket_name}/prefix)
  assert_in "$in_sync" "1100 file(s) added"
  out_sync=$(aws_s7 sync enc+s3://${bucket_name}/prefix file://"$test_dir/data/out")
  assert_in "$out_sync" "1100 file(s) added"
  diff -r "$test_dir/data/in" "$test_dir/data/out"
  diff_exit="$?"
  assert_eq "$diff_exit" "0"

  # Clear bucket
  rm -r "$test_dir/data/in"
  mkdir -p "$test_dir/data/in"
  aws_s7 sync file://"$test_dir/data/in" enc+s3://${bucket_name}/prefix > /dev/null
}

function test_s3_restore() {
  test_dir="$1"
  bucket_name="$2"
  mkdir -p "$test_dir"/data/{in,out}
  echo "test data" > "$test_dir/data/in/test.txt"
  in_sync=$(aws_s7 sync --storage-class=GLACIER file://"$test_dir/data/in" enc+s3://${bucket_name}/prefix)
  assert_in "$in_sync" "1 file(s) added"
  aws_s7 restore --restore-request="{\"Days\":1,\"GlacierJobParameters\":{\"Tier\":\"Expedited\"}}" s3://${bucket_name}/prefix > /dev/null
  # Per https://docs.aws.amazon.com/AmazonS3/latest/API/API_RestoreObject.html,
  # For all but the largest archived objects (250 MB+), data accessed using Expedited retrievals are typically made available within 1-5 minutes.
  sleep 300
  out_sync=$(aws_s7 sync enc+s3://${bucket_name}/prefix file://"$test_dir/data/out")
  assert_in "$out_sync" "1 file(s) added"
  diff -r "$test_dir/data/in" "$test_dir/data/out"
  diff_exit="$?"
  assert_eq "$diff_exit" "0"

  # Clear bucket
  rm "$test_dir/data/in/test.txt"
  aws_s7 sync file://"$test_dir/data/in" enc+s3://${bucket_name}/prefix > /dev/null
}

function test_s3_restore_after_restore() {
  test_dir="$1"
  bucket_name="$2"
  mkdir -p "$test_dir"/data/{in,out}
  echo "test data" > "$test_dir/data/in/test1.txt"
  aws_s7 sync --storage-class=GLACIER file://"$test_dir/data/in" enc+s3://${bucket_name}/prefix > /dev/null
  aws_s7 restore --restore-request="{\"Days\":1,\"GlacierJobParameters\":{\"Tier\":\"Expedited\"}}" s3://${bucket_name}/prefix > /dev/null
  echo "test data" > "$test_dir/data/in/test2.txt"
  aws_s7 sync --storage-class=GLACIER file://"$test_dir/data/in" enc+s3://${bucket_name}/prefix > /dev/null
  aws_s7 restore --restore-request="{\"Days\":1,\"GlacierJobParameters\":{\"Tier\":\"Expedited\"}}" s3://${bucket_name}/prefix > /dev/null
  # Per https://docs.aws.amazon.com/AmazonS3/latest/API/API_RestoreObject.html,
  # For all but the largest archived objects (250 MB+), data accessed using Expedited retrievals are typically made available within 1-5 minutes.
  sleep 300
  out_sync=$(aws_s7 sync enc+s3://${bucket_name}/prefix file://"$test_dir/data/out")
  assert_in "$out_sync" "2 file(s) added"
  diff -r "$test_dir/data/in" "$test_dir/data/out"
  diff_exit="$?"
  assert_eq "$diff_exit" "0"

  # Clear bucket
  rm "$test_dir"/data/in/{test1,test2}.txt
  aws_s7 sync file://"$test_dir/data/in" enc+s3://${bucket_name}/prefix > /dev/null
}

function test_s3_increase_partsize() {
  test_dir="$1"
  bucket_name="$2"
  mkdir -p "$test_dir"/data/{in,out}
  fallocate -l 60G "${test_dir}/data/in/data.img"
  in_sync=$(aws_s7 sync --storage-class=STANDARD file://"$test_dir/data/in" s3://${bucket_name}/prefix)
  assert_in "$in_sync" "1 file(s) added"
  assert_in "$in_sync" "Increasing part size to"
}


function s7() {
  ./s7 --secrets=<(echo "{\"password\":\"secret\"}") "$@"
}

function aws_s7() {
  ./s7 --secrets=<(echo "{\"password\":\"secret\", \"accessKeyId\":\"$AWS_ACCESS_KEY_ID\", \"secretAccessKey\":\"$AWS_SECRET_ACCESS_KEY\", \"sessionToken\":\"$AWS_SESSION_TOKEN\", \"region\":\"$AWS_DEFAULT_REGION\"}") "$@"
}

function assert_eq() {
  if [[ "$1" != "$2" ]]
  then
    echo "Assertion failed!"
    echo "$1 != $2"
    exit 1
  fi
}

function assert_in() {
  if [[ "$1" != *"$2"* ]]
  then
    echo "Assertion failed!"
    echo "$1 != *$2*"
    exit 1
  fi
}

function make_directory() {
  directory="$1"
  clean_directory "$directory"
  mktemp -d "$directory"
}

function clean_directory() {
  directory="$1"
  if [[ -d "$directory" ]]
  then
    rm -r "$directory"
  fi
}

function make_bucket() {
  random_hex=$(od --address-radix=n --read-bytes=16 --format="x" /dev/urandom | tr -d ' \n')
  bucket_name="s7tests-${random_hex}"
  aws s3 mb "s3://${bucket_name}" > /dev/null
  echo "$bucket_name"
}

function remove_bucket() {
  bucket_name="$1"
  aws s3 rb --force "s3://${bucket_name}"
}

main
