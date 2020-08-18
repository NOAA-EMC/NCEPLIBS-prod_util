set(EXENAME ndate)
add_executable(${EXENAME} ndate.f)
target_link_libraries(${EXENAME} w3nco::w3nco_4)

install(TARGETS ${EXENAME}
  RUNTIME DESTINATION ${CMAKE_INSTALL_PREFIX}/bin)
