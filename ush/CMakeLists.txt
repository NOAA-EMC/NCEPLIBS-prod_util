list(APPEND _ushPrograms
  compath.py
  cpfs
  cpreq
  date2jday.sh
  err_chk
  err_exit
  finddate.sh
  getsystem.pl
  mail.py
  postmsg
  prep_step
  setpdy.sh
  startmsg
)

install(PROGRAMS ${_ushPrograms}
        DESTINATION ${CMAKE_INSTALL_PREFIX}/bin)
