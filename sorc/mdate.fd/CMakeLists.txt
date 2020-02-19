set(EXENAME mdate)
set(EXE_SRC mdate.f)

add_executable(${EXENAME} ${EXE_SRC})
target_link_libraries(${EXENAME} w3nco_4)

install(TARGETS ${EXENAME} RUNTIME DESTINATION ${CMAKE_INSTALL_PREFIX}/bin)
