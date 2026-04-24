#!/bin/bash

# Written by Gemini v3.1 Pro. Modified and reviewed by a human.

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_UNDER_TEST=$( realpath "${TEST_DIR}/../ush/err_exit" )

# --- Framework UI ---
PASSED=0
FAILED=0
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

pass() {
    echo -e "${GREEN}PASS:${NC} $1"
    ((PASSED++))
}

fail() {
    echo -e "${RED}FAIL:${NC} $1\n    -> $2\n"
    ((FAILED++))
}

# --- Setup & Teardown ---
setup() {
    # Take an optional argument for the scheduler type
    # Usage: setup [pbs|slurm|lsf]

    export TEST_TEMP_DIR="$(mktemp -d)"

    # Unset all potential environment variables to ensure a clean state
    unset jobid pgm err DATA pgmout SENDECF ECF_HOST ECF_JOBOUT PBS_JOBID ECF_NAME JOBID KILLJOB
    unset SLURM_JOB_ID SLURM_SLEEP LSF_JOBID qdel scancel bkill

    # Provide a default ECF_NAME so the script doesn't abort early on ${ECF_NAME:?}
    export ECF_NAME="mock_ecf_job"

    # Mock external commands
    module() { echo "mock_module $@"; }
    export -f module

    timeout() {
        local duration=$1
        shift
        # Allow evaluation of trailing mock commands
        echo "mock_timeout ${duration}" $("$@")
    }
    export -f timeout

    ecflow_client() { echo "mock_ecflow_client $@"; }
    export -f ecflow_client

    ssh() { echo "mock_ssh $@"; }
    export -f ssh

    qdel() { echo "mock_qdel $@"; }

    scancel() { echo "mock_scancel $@"; }

    bkill() { echo "mock_bkill $@"; }

    if [[ $# -gt 0 ]]; then
        case "$1" in
            pbs)
                export PBS_JOBID="12345.scheduler"
                export -f qdel
                ;;
            slurm)
                export SLURM_JOB_ID="67890"
                export SLURM_SLEEP="0"
                export -f scancel
                ;;
            lsf)
                export LSF_JOBID="54321"
                export -f bkill
                ;;
            *)
                # Do not set any scheduler variables.
                ;;
        esac
    fi

    # Clean up any residual local files
    rm -f errfile dummy_pgmout
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
    rm -f errfile dummy_pgmout
    unset jobid pgm err DATA pgmout SENDECF ECF_HOST ECF_JOBOUT PBS_JOBID ECF_NAME JOBID KILLJOB
    unset SLURM_JOB_ID SLURM_SLEEP LSF_JOBID qdel scancel bkill
}

# --- Test Cases ---

test_message_construction() {
    setup pbs
    export jobid="999"
    export pgm="data_ingest.sh"
    export err="127"

    local output
    output=$($SCRIPT_UNDER_TEST "Critical failure" 2>&1)

    if [[ "$output" == *"FATAL ERROR: Critical failure, ERROR IN data_ingest.sh RETURN CODE 127"* ]]; then
        pass "$FUNCNAME"
    else
        fail "$FUNCNAME" "Message construction failed. Output: $output"
    fi
    teardown
}

test_data_warning_when_unset() {
    setup pbs
    # DATA is intentionally unset
    local output
    output=$($SCRIPT_UNDER_TEST 2>&1)

    if [[ "$output" == *"WARNING: DATA variable not defined"* ]]; then
        pass "$FUNCNAME"
    else
        fail "$FUNCNAME" "Did not find expected warning. Output: $output"
    fi
    teardown
}

test_ls_when_data_set() {
    setup pbs
    export DATA="$TEST_TEMP_DIR"
    export LMOD_SH_DBG_ON=1

    local output
    output=$(bash -x $SCRIPT_UNDER_TEST 2>&1)

    if [[ "$output" == *"ls -ltr $TEST_TEMP_DIR"* ]]; then
        pass "$FUNCNAME"
    else
        fail "$FUNCNAME" "Failed to find 'ls -ltr $TEST_TEMP_DIR' call. Output: "
        echo "$output"
    fi

    unset LMOD_SH_DBG_ON
    teardown
}

test_errfile_appends_to_pgmout() {
    setup pbs
    export pgmout="dummy_pgmout"
    touch dummy_pgmout
    echo "Simulated error log entry" > errfile

    local output
    output=$($SCRIPT_UNDER_TEST 2>&1)

    if grep -q "contents of errfile" dummy_pgmout && grep -q "Simulated error log entry" dummy_pgmout; then
        pass "$FUNCNAME"
    else
        fail "$FUNCNAME" "File was not appended correctly."
    fi
    teardown
}

test_sendecf_yes() {
    setup pbs
    export SENDECF="YES"
    export ECF_HOST="my-ecflow-host"
    export ECF_JOBOUT="/path/to/ecf.out"

    local output
    output=$($SCRIPT_UNDER_TEST 2>&1)

    if [[ "$output" == *"mock_timeout 30 mock_ecflow_client --msg mock_ecf_job: Job UNKNOWN failed"* ]] && \
       [[ "$output" == *"mock_timeout 30 mock_ssh my-ecflow-host echo"* ]] && \
       [[ "$output" == *">> $ECF_JOBOUT"* ]]; then
        pass "$FUNCNAME"
    else
        fail "$FUNCNAME" "Mocks were not called properly. Output: $output"
    fi
    teardown
}

test_ecflow_log_no_ecf_jobout() {
    setup pbs
    export SENDECF="YES"
    export ECF_JOBOUT="/path/to/ecf.out"

    local output
    output=$($SCRIPT_UNDER_TEST 2>&1)

    if [[ "$output" == *"FATAL ERROR Unable to write to ecflow server as either ECF_HOST or ECF_JOBOUT are undefined!!"* ]]; then
        pass "$FUNCNAME"
    else
        fail "$FUNCNAME" "ecFlow log written when ECF_HOST is empty. Output: $output"
    fi
    teardown
}

test_ecflow_log_no_ecf_host() {
    setup pbs
    export SENDECF="YES"
    export ECF_HOST="my-ecflow-host"

    local output
    output=$($SCRIPT_UNDER_TEST 2>&1)

    if [[ "$output" == *"FATAL ERROR Unable to write to ecflow server as either ECF_HOST or ECF_JOBOUT are undefined!!"* ]]; then
        pass "$FUNCNAME"
    else
        fail "$FUNCNAME" "ecFlow log written when ECF_JOBOUT is empty. Output: $output"
    fi
    teardown
}

test_ecflow_log_no_ecf_jobout_no_ecf_host() {
    setup pbs
    export SENDECF="YES"

    local output
    output=$($SCRIPT_UNDER_TEST 2>&1)

    if [[ "$output" == *"FATAL ERROR Unable to write to ecflow server as either ECF_HOST or ECF_JOBOUT are undefined!!"* ]]; then
        pass "$FUNCNAME"
    else
        fail "$FUNCNAME" "ecFlow log written when ECF_HOST and ECF_JOBOUT are empty. Output: $output"
    fi
    teardown
}

test_kill_via_ecflow_when_no_pbs() {
    setup
    # PBS_JOBID is unset

    export SENDECF="YES"

    local output
    output=$($SCRIPT_UNDER_TEST 2>&1)

    if [[ "$output" == *"mock_ecflow_client --kill=mock_ecf_job"* ]]; then
        pass "$FUNCNAME"
    else
        fail "$FUNCNAME" "Expected ecflow kill call missing. Output: $output"
    fi
    teardown
}

test_kill_via_ecflow_no_ecf_name() {
    setup

    export SENDECF="YES"
    export ECF_HOST="my-ecflow-host"
    export ECF_JOBOUT="/path/to/ecf.out"
    export ECF_NAME=""
    export JOBID="12345.scheduler"

    local output
    output=$($SCRIPT_UNDER_TEST 2>&1)

    if [[ "$output" == *"FATAL ERROR Unable to kill ecflow job as ECF_NAME variable is not set!!"* ]]; then
        pass "$FUNCNAME"
    else
        fail "$FUNCNAME" "Expected qdel call missing or JOBID not set properly. Output: $output"
    fi
    teardown
}

test_kill_via_qdel_when_pbs_set() {
    setup pbs

    local output
    output=$($SCRIPT_UNDER_TEST 2>&1)

    if [[ "$output" == *"mock_qdel 12345.scheduler"* ]] && [[ "$output" != *"mock_ecflow_client --kill"* ]]; then
        pass "$FUNCNAME"
    else
        fail "$FUNCNAME" "Expected qdel call missing or ecflow called improperly. Output: $output"
    fi
    teardown
}

test_kill_via_qdel_no_pbs_jobid() {
    setup pbs
    unset PBS_JOBID

    local output
    output=$($SCRIPT_UNDER_TEST 2>&1)

    if [[ "$output" == *"Could not find a scheduler command or job ID to kill the current job"* ]] && \
        [[ "$output" == *"KILLJOB = qdel"* ]] && \
        echo "$output" | grep -qE "^JOBID   = $" ; then
        echo "$output"
        pass "$FUNCNAME"
    else
        fail "$FUNCNAME" "Expected failure did not occur when JOBID is empty. Output: $output"
    fi
    teardown
}

test_kill_via_scancel_when_slurm_set() {
    setup slurm
    export JOBID="$SLURM_JOB_ID"

    local output
    output=$($SCRIPT_UNDER_TEST 2>&1)

    if [[ "$output" == *"mock_scancel 67890"* ]] && [[ "$output" != *"mock_ecflow_client --kill"* ]]; then
        pass "$FUNCNAME"
    else
        fail "$FUNCNAME" "Expected scancel call missing or ecflow called improperly. Output: $output"
    fi
    teardown
}

test_kill_via_scancel_no_slurm_job_id() {
    setup slurm
    unset SLURM_JOB_ID

    local output
    output=$($SCRIPT_UNDER_TEST 2>&1)

    if [[ "$output" == *"Could not find a scheduler command or job ID to kill the current job"* ]] && \
        [[ "$output" == *"KILLJOB = scancel"* ]] && \
        echo "$output" | grep -qE "^JOBID   = $" ; then
        echo "$output"
        pass "$FUNCNAME"
    else
        fail "$FUNCNAME" "Expected failure did not occur when JOBID is empty. Output: $output"
    fi
    teardown
}

test_kill_via_bkill_when_lsf_set() {
    setup lsf
    export JOBID="$LSF_JOBID"

    local output
    output=$($SCRIPT_UNDER_TEST 2>&1)

    if [[ "$output" == *"mock_bkill 54321"* ]] && [[ "$output" != *"mock_ecflow_client --kill"* ]]; then
        pass "$FUNCNAME"
    else
        fail "$FUNCNAME" "Expected bkill call missing or ecflow called improperly. Output: $output"
    fi
    teardown
}

test_kill_via_bkill_no_lsf_job_id() {
    setup lsf
    unset LSF_JOBID

    local output
    output=$($SCRIPT_UNDER_TEST 2>&1)

    if [[ "$output" == *"Could not find a scheduler command or job ID to kill the current job"* ]] && \
        [[ "$output" == *"KILLJOB = bkill"* ]] && \
        echo "$output" | grep -qE "^JOBID   = $" ; then
        echo "$output"
        pass "$FUNCNAME"
    else
        fail "$FUNCNAME" "Expected failure did not occur when JOBID is empty. Output: $output"
    fi
    teardown
}

# --- Test Runner ---

echo "Starting pure Bash test suite for $SCRIPT_UNDER_TEST..."
echo "-------------------------------------------------------------"

# Check if target script is executable
if [ ! -x "$SCRIPT_UNDER_TEST" ]; then
    echo "Applying executable permissions to $SCRIPT_UNDER_TEST..."
    chmod +x "$SCRIPT_UNDER_TEST"
fi

# Execute all tests
test_message_construction
test_data_warning_when_unset
test_ls_when_data_set
test_errfile_appends_to_pgmout
test_sendecf_yes
test_ecflow_log_no_ecf_jobout
test_ecflow_log_no_ecf_host
test_ecflow_log_no_ecf_jobout_no_ecf_host
test_kill_via_ecflow_when_no_pbs
test_kill_via_ecflow_no_ecf_name
# These tests will not work if qdel, scancel, or bkill are in the PATH, so skip if they are detected.
# Test all cases if the commands are not found, otherwise only test the found commands.
if command -v qdel &> /dev/null; then
    test_kill_via_qdel_when_pbs_set
    test_kill_via_qdel_no_pbs_jobid
elif command -v scancel &> /dev/null; then
    test_kill_via_scancel_when_slurm_set
    test_kill_via_scancel_no_slurm_job_id
elif command -v bkill &> /dev/null; then
    test_kill_via_bkill_when_lsf_set
    test_kill_via_bkill_no_lsf_job_id
else
    test_kill_via_qdel_when_pbs_set
    test_kill_via_qdel_no_pbs_jobid
    test_kill_via_scancel_when_slurm_set
    test_kill_via_scancel_no_slurm_job_id
    test_kill_via_bkill_when_lsf_set
    test_kill_via_bkill_no_lsf_job_id
fi

echo "-------------------------------------------------------------"
echo "Test Run Complete: $PASSED passed, $FAILED failed."

# Return standard exit codes for CI/CD compatibility
if [ "$FAILED" -ne 0 ]; then
    exit 1
else
    exit 0
fi
