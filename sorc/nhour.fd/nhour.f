C> @file
C> COMPUTE FORECAST HOUR
C> @author IREDELL @date 1998-08-18
C>
C> PROGRAM TO COMPUTE FORECAST HOUR
C> GIVEN THE VERIFYING DATE AND THE INITIAL DATE.
C>
C> PROGRAM HISTORY LOG:
C> -  95-02-28  IREDELL
C> -  97-09-22  IREDELL  4-DIGIT YEAR ALLOWED; 2-DIGIT YEAR STANDARDIZED
C> -  98-03-25  IREDELL  4-DIGIT YEAR FOR ALL DATES.  A 2-DIGIT YEAR WILL
C>                      BE INTERPRETED AS A YEAR IN THE FIRST CENTURY
C>                      WHICH SHOULD BE ALL RIGHT BEFORE THE YEAR 2000.
C>                      STANDARD ERROR WARNINGS WILL BE GIVEN FOR SUCH
C>                      DATES UNTIL 1 SEPT 1998 AFTER WHICH NHOUR ABORTS.
C>                      THE NEW Y2K-COMPLIANT W3LIB PACKAGE IS USED.
C> - 1998-08-17  IREDELL  DROP-DEAD DATE RESET TO 1 SEPT 1999
C> - 1999-04-22  Gilbert  Changed subroutine EXIT(N) to ERREXIT(N) so that
C>                      error return values are passed back to the shell
C>                      properly.
C> - 1999-09-02  IREDELL  STANDARDIZED 4-DIGIT YEAR AS IN NDATE
C>
C> USAGE:      nhour vdate [idate]
C>   INPUT ARGUMENT LIST:
C>   -  VDATE    - VERIFYING DATE IN YYYYMMDDHH FORMAT.
C>   -  IDATE    - INITIAL DATE IN YYYYMMDDHH FORMAT.
C>                IDATE DEFAULTS TO THE UTC DATE AND HOUR.
C>   OUTPUT ARGUMENT LIST:
C>   -  NHOUR    - FORECAST HOUR
C>                LEADING ZEROES ADDED TO MAKE IT AT LEAST TWO DIGITS.
C>                LEADING MINUS SIGN ADDED IF IDATE COMES AFTER VDATE.
C>   EXIT STATES:
C>   -  0      - SUCCESS
C>   -  1      - FAILURE; INVALID ARGUMENT
C>   -  2      - FAILURE; INCORRECT NUMBER OF ARGUMENTS
C>
C> SUBPROGRAMS CALLED:
C> -  IARGC           GET NUMBER OF ARGUMENTS
C> -  GETARG          GET ARGUMENT
C> -  W3DIFDAT        RETURN A TIME INTERVAL BETWEEN TWO DATES
C> -  W3PRADAT        FORMAT A DATE AND TIME INTO CHARACTERS
C> -  W3UTCDAT        RETURN THE UTC DATE AND TIME
C> -  ERRMSG          WRITE A MESSAGE TO STDERR
C> -  ERREXIT         EXIT PROGRAM
C>
      PROGRAM NHOUR
      CHARACTER*256 CARG,CFMT
      INTEGER IDAT(8),JDAT(8)
      REAL RINC(5)
      LOGICAL W3VALDAT
C - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
C  CHECK NUMBER OF ARGUMENTS
      NARG=IARGC()
      IF(NARG.LT.1.OR.NARG.GT.2) THEN
        CALL ERRMSG('nhour: Incorrect number of arguments')
        CALL EUSAGE
        CALL ERREXIT(2)
      ENDIF
C - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
C  GET AND CHECK FIRST ARGUMENT (VERIFYING DATE)
      CALL GETARG(1,CARG)
      NCARG=LEN_TRIM(CARG)
      WRITE(CFMT,'("(I",I2,",3I2)")') NCARG-6
      JDAT=0
      READ(CARG,CFMT,IOSTAT=IRET) JDAT(1),JDAT(2),JDAT(3),JDAT(5)
      IF(IRET.NE.0.OR..NOT.W3VALDAT(JDAT)) THEN
        CALL ERRMSG('nhour: Invalid date '//CARG(1:NCARG))
        CALL EUSAGE
        CALL ERREXIT(1)
      ENDIF
C - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
C  GET AND CHECK SECOND ARGUMENT (INITIAL DATE)
      IF(NARG.GE.2) THEN
        CALL GETARG(2,CARG)
        NCARG=LEN_TRIM(CARG)
        WRITE(CFMT,'("(I",I2,",3I2)")') NCARG-6
        IDAT=0
        READ(CARG,CFMT,IOSTAT=IRET) IDAT(1),IDAT(2),IDAT(3),IDAT(5)
        IF(IRET.NE.0.OR..NOT.W3VALDAT(IDAT)) THEN
          CALL ERRMSG('nhour: Invalid date '//CARG(1:NCARG))
          CALL EUSAGE
          CALL ERREXIT(1)
        ENDIF
      ELSE
        CALL W3UTCDAT(IDAT)
      ENDIF
C - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
C  COMPUTE AND PRINT HOUR DIFFERENCE
      CALL W3DIFDAT(JDAT,IDAT,2,RINC)
      IHOUR=NINT(RINC(2))
      NDIG=LOG10(ABS(IHOUR)+0.5)+1
      NDIG=MAX(NDIG,2)
      IF(IHOUR.LT.0) NDIG=NDIG+1
      WRITE(CFMT,'("(I",I2,".2)")') NDIG
      PRINT CFMT,IHOUR
C - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      CONTAINS
C - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
C  WRITE USAGE
      SUBROUTINE EUSAGE
      CALL ERRMSG('Usage: nhour vdate [idate]')
      ENDSUBROUTINE
C - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      ENDPROGRAM
