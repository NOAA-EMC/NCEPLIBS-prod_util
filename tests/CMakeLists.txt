# This is the CTest config for prod_util
# Alex Richert, Sep 2023
add_test(NAME test_nhour COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/test_nhour.sh)
add_test(NAME test_ndate COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/test_ndate.sh)
add_test(NAME test_mdate COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/test_mdate.sh)
