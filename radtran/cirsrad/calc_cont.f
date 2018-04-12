      SUBROUTINE CALC_CONT(WING,MAXDV,NLAYER,NGAS,PRESS,TEMP,
     1 FRAC,IDGAS,ISOGAS,IPROC,IB)
C     $Id:
C***********************************************************************
C_TITL:	CALC_CONT.f
C
C_DESC:	Calculate the line contributions to the continuum bins
C
C_ARGS:	Input variables:
C	WING		REAL	Bin width.
C	MAXDV		REAL	Line wing cut-off
C	NLAYER		INTEGER	Number of Layers
C	NGAS		INTEGER	Number of gases
C	PRESS(NLAYER)	REAL	Total pressure [atm].
C	TEMP(NLAYER)	REAL	Temperature [Kelvin].
C	FRAC(NLAYER,NGAS) REAL Fractional abundance of each gas
C	IDGAS(NGAS)	INTEGER	Gas ID
C       ISOGAS(NGAS)	INTEGER Isotope ID
C	IPROC(NGAS)	INTEGER	Line wing processing parameter.
C	IB		INTEGER Buffer 1 or 2
C
C	../includes/*.f variables:
C	VLIN(2,MAXLIN)	REAL*8	Line position [cm^-1].
C	SLIN(2,MAXLIN)	REAL*8	Line strength [cm^-1 molecule^-1 cm^-2] at
C				STP.
C	ALIN(2,MAXLIN)	REAL	Air-broadened halfwidth [cm^-1/atm] @ STP.
C	ELIN(2,MAXLIN)	REAL	Lower state energy line position [cm^-1].
C	IDLIN(2,MAXLIN)	REAL	Air Force Geospace Lab. identifier.
C	SBLIN(2,MAXLIN)	REAL	Self broadening coefficient. NOTE: the
C				self-broadening coefficient used in this
C				program is the 'air'-broadened halfwidth
C				minus the self-broadened halfwidth.
C	TDW(2,MAXLIN)	REAL	Temperature coefficient of air-broadened
C				halfwidth.
C	TDWS(2,MAXLIN)	REAL	Temperature coefficient of self-broademed
C				halfwidth.
C	DOUBV(2,MAXLIN)	REAL	The inversion doublet separation (only
C				applies to longwave NH3 lines at present.   
C	LLQ(2,MAXLIN)	CHARA*9	The lower state local quanta index.
C	NLINE(2)	INTEGER	Number of lines stored in each buffer
C
C_HIST:	15apr11	PGJI	Modified from lbl_kcont.f
C	29feb12	PGJI	Updated for Radtrans2.0
C
C***************************** VARIABLES *******************************

      IMPLICIT NONE


      INTEGER NGAS,IDGAS(NGAS),ISOGAS(NGAS),IPROC(NGAS),NLAYER
      REAL VMIN,VMAX,WING,VREL,MAXDV

      INCLUDE '../includes/arrdef.f'
C     Continuum and temperature parameter variables ...
      INCLUDE '../includes/contdef.f'
      REAL TRATIO,TSTIM
      REAL FRAC(MAXLAY,MAXGAS),PRESS(NLAYER),TEMP(NLAYER)

      INCLUDE '../includes/lincomc.f'
C ../includes/lincom.f stores the linedata variables (including MAXLIN,
C VLIN, SLIN, ALIN, ELIN, SBLIN, TDW, TDWS and that lot).


C     General variables ...
      REAL DV,LINECONTRIB,VV,X,FNH3,FH2
      INTEGER I,J,K,L,LINE,IBIN,CURBIN,IGAS,IB
      INTEGER LAYER
      REAL DPEXP,ABSCO,Y,CONVAL
       
C     GASCON switches
      INCLUDE '../includes/gascom.f'

C******************************** CODE *********************************


      
      DO 13 LINE=1,NLINE(IB)
       CURBIN = 1 + INT((VLIN(IB,LINE)-VBIN(1))/WING)
       IGAS=IDLIN(IB,LINE)
       DO 15 J=1,NBIN
	
C       Computing continuum for all except adjacent bins
        IF(ABS(CURBIN-J).LE.1)GOTO 15

        DO 21 K=1,IORDP1
          VV = CONWAV(K) + VBIN(J) 
          DV = (VV - VLIN(IB,LINE))
C         Don't calculate at wavenumbers more than MAXDV away
          IF(ABS(DV).LE.MAXDV)THEN

           DO 101 LAYER=1,NLAYER


             IF(IDGAS(IGAS).EQ.1.AND.IH2O.GT.0.AND.
     &         ABS(DV).GT.25.0)THEN
C              Don't calc continuum more than 25cm-1 from H2O lines
C              if H2O continuum is turned on
               CONVAL = 0.0

             ELSE
              FH2=-1.
              FNH3=-1.
              CONVAL = LINECONTRIB(IPROC(IGAS),IDGAS(IGAS),VV,
     1       TCORDW(LAYER,IGAS),TCORS1(LAYER,IGAS),TCORS2(LAYER),
     2       PRESS(LAYER),TEMP(LAYER),FRAC(LAYER,IGAS),VLIN(IB,LINE),
     3       SLIN(IB,LINE),ELIN(IB,LINE),ALIN(IB,LINE),SBLIN(IB,LINE),
     4       TDW(IB,LINE),TDWS(IB,LINE),LLQ(IB,LINE),DOUBV(IB,LINE),
     5       FNH3,FH2)

             ENDIF

            CONVALS(K,LAYER,J)=CONVALS(K,LAYER,J)+CONVAL

101        CONTINUE

          ENDIF

21       CONTINUE

15     CONTINUE

13    CONTINUE


C     Convert continuum values to polynomial coefficients
      DO 200 LAYER=1,NLAYER
       DO 202 J=1,NBIN
        DO 205 K=1,IORDP1
         CONTINK(K,LAYER,J)=0.0
         DO 210 L=1,IORDP1
          CONTINK(K,LAYER,J) = CONTINK(K,LAYER,J) + 
     &         UNIT(L,K)*CONVALS(L,LAYER,J)
210      CONTINUE
205     CONTINUE
202    CONTINUE
200   CONTINUE

      RETURN

      END
************************************************************************
************************************************************************
