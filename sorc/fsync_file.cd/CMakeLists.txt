set(EXE_SRC fsync_file.c)
set(EXENAME fsync_file)

add_executable(${EXENAME} ${EXE_SRC})

install(TARGETS ${EXENAME} RUNTIME DESTINATION ${CMAKE_INSTALL_PREFIX}/bin)
