#!/bin/bash
set -x

NDATE_REF_A=$(TZ=UT date +%Y%m%d%H)
NDATE_TEST_A=$(ndate)
if [ "$NDATE_REF_A" -ne "$NDATE_TEST_A" ]; then
  echo "ndate (test 1) reference output '$NDATE_REF_A' does not match test output '$NDATE_TEST_A'"
  rc=1
fi

NDATE_REF_B=2023010206
NDATE_TEST_B=$(ndate 12 2023010118)
if [ "$NDATE_REF_B" -ne "$NDATE_TEST_B" ]; then
  echo "ndate (test 2) reference output '$NDATE_REF_B' does not match test output '$NDATE_TEST_B'"
  rc=1
fi

exit $rc
