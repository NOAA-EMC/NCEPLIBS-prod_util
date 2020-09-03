set(EXENAME nhour)
add_executable(${EXENAME} nhour.f)
target_link_libraries(${EXENAME} PRIVATE w3nco::w3nco_4)

install(TARGETS ${EXENAME}
  RUNTIME DESTINATION ${CMAKE_INSTALL_PREFIX}/bin)
