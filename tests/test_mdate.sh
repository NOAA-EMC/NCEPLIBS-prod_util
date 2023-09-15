#!/bin/bash
set -x

MDATE_REF_A=$(TZ=UTC date +%Y%m%d%H%M)
MDATE_TEST_A=$(mdate)
if [ "$MDATE_REF_A" -ne "$MDATE_TEST_A" ]; then
  echo "mdate (test 1) reference output '$MDATE_REF_A' does not match test output '$MDATE_TEST_A'"
  rc=1
fi

MDATE_REF_B=202309141214
MDATE_TEST_B=$(mdate -20 202309141234)
if [ "$MDATE_REF_B" -ne "$MDATE_TEST_B" ]; then
  echo "mdate (test 2) reference output '$MDATE_REF_B' does not match test output '$MDATE_TEST_B'"
  rc=1
fi

exit $rc
