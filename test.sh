#!/bin/bash

# Default is localhost
export SERVER_PATH=:8080

# Install httpie
if ! command -v http &>/dev/null ; then
	echo "httpie not installed, 'apt-get install httpie', 'yum install -y httpie', 'brew install httpie'"
	exit 1
fi

# Tester functions
NORMAL='\033[0m'
RED='\033[31m'
GREEN="\033[0;32m"
LGREEN='\033[1;32m'

function fail() {
	echo  -e " \033[;31m ~ [FAIL] $1 \033[0m "
	exit 1
}

function pass () {
	echo  -e " \033[;32m ~ [pass] $1 \033[0m "
}

function msg () {
	echo "[INFO] $1"
}

function assert_status_code () {
	msg "http $1 $2"
	status_code="$(http -h --timeout=2 $1 $SERVER_PATH$2 | grep HTTP/ | cut -d ' ' -f 2)"
	if [ "$status_code" != "$3" ]
	then
		fail "request $2 $1 response status code expected:$3 actual:$status_code"
	else
		pass "request $2 $1 response status code $3"
	fi
}

function assert_resp_body () {
	msg "http $1 $2"
	body="$(http -b --timeout=2 $1 $SERVER_PATH$2)"
	if [ "$body" != "$3" ]
	then
		fail "request $2 $1 response body \n\n   expected:$3 \n   actual:$body"
	else
		pass "request $2 $1 response body $3"
	fi
}

function assert_with_args_status_code () {
	msg "http $1 $2"
	status_code="$(http -h --timeout=2 $1 $SERVER_PATH$2 "$3"| grep HTTP/ | cut -d ' ' -f 2)"
	if [ "$status_code" != "$4" ]
	then
		fail "request $2 $1 response status code expected:$3 actual:$status_code"
	else
		pass "request $2 $1 response status code $3"
	fi
}

function assert_with_args_resp_body () {
	msg "http $1 $2; args: $3"
	body="$(http -b --timeout=2 $1 $SERVER_PATH$2 "$3")"
	if [ "$body" != "$4" ]
	then
		fail "request $2 $1 response body \n\n   expected:$4 \n   actual:$body"
	else
		pass "request $2 $1 response body $3"
	fi
}

function assert_file_download () {
	msg "http $1 sha256 hash: $2"

	hash="$(http -d --timeout=2 GET $SERVER_PATH$1 | sha256sum)"
	if [ "$hash" != "$2" ]
	then
		fail "expected:$2 \n   actual:$hash"
	else
		pass "expected:$2 \n   actual:$hash"
	fi
}

# Test cases
clear

echo "test 2xx error code"
	http --check-status --timeout=2 get $SERVER_PATH &> /dev/null
	if [ "$?" != "0" ]
	then
		fail "error code: $?"
	else
		pass "successful error code"
	fi
echo

echo "test GET status line"
	assert_status_code "GET" "/" 200
echo

echo "test GET body"
# $'<STRING>' will automatically escape chars
	assert_resp_body "GET" "/" $'<html><body><p><a href="index.html">index.html</a></p><p><a href="folder">folder</a></p><p><a href="img.JPG">img.JPG</a></p></html></body>'
echo

echo "test HEAD status line"
	assert_status_code "HEAD" "/" 200
echo

echo "test HEAD empty body"
	assert_resp_body "HEAD" "/" $''
echo

echo "test 404"
	assert_status_code "GET" "/fakefile.html" 404
echo

echo "test If-Modified-Since status line (before) with file modified on Sun, 22 Jan 2017 12:20:45 GMT"
	assert_with_args_status_code "GET " "/index.html" "If-Modified-Since: Sat, 21 Jan 2017 03:40:04 GMT" 200
echo

echo "test If-Modified-Since status line (after) with file modified on Sun, 22 Jan 2017 12:20:45 GMT"
	assert_with_args_status_code "GET " "/index.html" "If-Modified-Since: Mon, 13 Feb 2017 03:40:04 GMT" 304
echo

echo "test If-Unmodified-Since (after) with file modified on Sun, 22 Jan 2017 12:20:45 GMT"
	assert_with_args_status_code "GET " "/index.html" "If-Unmodified-Since: Mon, 13 Feb 2017 03:40:04 GMT" 200
echo

echo "test If-Unmodified-Since (before) with file modified on Sun, 22 Jan 2017 12:20:45 GMT"
	assert_with_args_status_code "GET " "/index.html" "If-Unmodified-Since: Sat, 21 Jan 2017 03:40:04 GMT" 412
echo

echo "test POST status line"
	assert_with_args_status_code "--form POST" "/" "key1=value1&key2=value2" 200
echo

echo "test GET body"
	assert_with_args_resp_body "GET" "/img.JPG" $''
echo

echo "test binary transfer"
    assert_file_download "/img.JPG" "27e7683f0604c020cab0b7f92ae5442c90b8e7f197851754aa45c84a9be21003"
echo