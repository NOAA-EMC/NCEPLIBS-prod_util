#!/bin/bash
set -x
exe=${1:-nhour}

NHOUR_REF_A=00
NHOUR_TEST_A=$(TZ=UT faketime '20230920 00:00' $exe 2023092000)
if [ "$NHOUR_REF_A" -eq "$NHOUR_TEST_A" ]; then
  pass=A
else
  echo "$exe (test 1) reference output '$NHOUR_REF_A' does not match test output '$NHOUR_TEST_A'"
fi

NHOUR_REF_B=27
NHOUR_TEST_B=$(TZ=UT faketime '20230920 00:00' $exe 2023092103)
if [ "$NHOUR_REF_B" -eq "$NHOUR_TEST_B" ]; then
  pass=${pass}B
else
  echo "$exe (test 2) reference output '$NHOUR_REF_B' does not match test output '$NHOUR_TEST_B'"
fi

NHOUR_REF_C=20
NHOUR_TEST_C=$($exe $(TZ=UT date -d 'today +27hours' +%Y%m%d%H) $(TZ=UT date -d 'today +7hours' +%Y%m%d%H))
if [ "$NHOUR_REF_C" -eq "$NHOUR_TEST_C" ]; then
  pass=${pass}C
else
  echo "$exe (test 3) reference output '$NHOUR_REF_C' does not match test output '$NHOUR_TEST_C'"
fi

if [ "$pass" != ABC ]; then
  exit 1
fi
