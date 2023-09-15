#!/bin/bash
set -x

NHOUR_REF_A=00
NHOUR_TEST_A=$(./nhour $(TZ=UT date -d 'today' +%Y%m%d%H))
if [ "$NHOUR_REF_A" -ne "$NHOUR_TEST_A" ]; then
  echo "nhour (test 1) reference output '$NHOUR_REF_A' does not match test output '$NHOUR_TEST_A'"
  rc=1
fi

NHOUR_REF_B=27
NHOUR_TEST_B=$(./nhour $(TZ=UT date -d 'today +27hours' +%Y%m%d%H))
if [ "$NHOUR_REF_B" -ne "$NHOUR_TEST_B" ]; then
  echo "nhour (test 2) reference output '$NHOUR_REF_B' does not match test output '$NHOUR_TEST_B'"
  rc=1
fi

NHOUR_REF_C=20
NHOUR_TEST_C=$(./nhour $(TZ=UT date -d 'today +27hours' +%Y%m%d%H) $(TZ=UT date -d 'today +7hours' +%Y%m%d%H))
if [ "$NHOUR_REF_C" -ne "$NHOUR_TEST_C" ]; then
  echo "nhour (test 3) reference output '$NHOUR_REF_C' does not match test output '$NHOUR_TEST_C'"
  rc=1
fi

exit $rc
