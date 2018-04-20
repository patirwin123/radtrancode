      SUBROUTINE CALC_LCO(VBIN,NBIN,WING,MAXDV,IPROC,IDGAS,TCORDW,
     1 TCORS1,TCORS2,PRESS,TEMP,FRAC,FNH3,FH2,VOUT,YOUT)
C     ****************************************************************
C     Function to calculate the LCO contribution for multiple line
C     broadening types.
C
C     Input variables:
C	IPROC	INTEGER	Line processing parameter
C	IDGAS	INTEGER	Gas ID
C	VV	REAL*8	Calculation wavenumber
C	TCORDW	REAL	Doppler line width coefficient
C	TCORS1 	REAL	Temperature coefficient 1
C	TCORS2 	REAL	Temperature coefficient 2
C	PRESS	REAL	Pressure
C	TEMP	REAL	Temperature
C	FRAC	REAL	Fraction
C	FNH3	REAL	Fraction of NH3 (needed of models 3 and 6)
C	FH2	REAL	Fraction of H2 (needed of models 3 and 6)
C	
C     ****************************************************************
      IMPLICIT NONE
      INTEGER IPROC,IDGAS,I,J,NBIN,J1,J2,I1,I2,NLCO,K
      INCLUDE '../includes/arrdef.f'
      INCLUDE '../includes/lcocom.f'      

      REAL VOUT(MAXBIN),YOUT(MAXBIN),XX(MLCO),YY(MLCO)
      REAL SUBLINE,ABSCO,X,Y,AD,TRATIO,DOUBV,WING,MAXDV
      REAL ALIN,SBLIN,ELIN,TDW,TDWS,TCORDW,TCORS1,TCORS2
      DOUBLE PRECISION SLIN,LNABSCO,VLIN,VV
      REAL DV,TSTIM,TS1,TS2,L1,L2,VBIN(MAXBIN)
      REAL V1,V2,F,WEIGHT(0:300),SUM
      REAL PRESS,TEMP,FRAC,FNH3,FH2,WY,DPEXP
      CHARACTER*15 LLQ

      DOUBV=0.
      LLQ='               '

      TRATIO = 296./TEMP


      DO I=1,NBIN
       VOUT(I)=VBIN(I)
       YOUT(I)=0.
      ENDDO
      VOUT(NBIN+1)=VBIN(NBIN)+WING
      YOUT(NBIN+1)=0.

C     Find range of wavelengths over which we need to calculate LCO contributiuon
      V1 = VOUT(1)-MAXDV
      V2 = VOUT(NBIN+1)+MAXDV

C     Now find LCO table entries
      J1 = 1 + INT((V1-VLCO(1))/LCOBINSIZE)
      J2 = 1 + INT((V2-VLCO(1))/LCOBINSIZE)
      IF(J1.LT.1)THEN
       PRINT*,'CALC_LCO wavenumber less than minimum'
       PRINT*,V1,VLCO(1)
       J1=1
      ENDIF
      IF(J2.GT.NBINLCO)THEN
       PRINT*,'CALC_LCO wavenumber greater than minimum'
       PRINT*,V2,VLCO(NBINLCO)
       J2=NBINLCO
      ENDIF


C     Calculate number of LCO steps we need to go either side of 
C     each LCO wavenumber to calculate wings
      NLCO = INT(MAXDV/LCOBINSIZE)

C     Initialise LCO absorption
      DO I = 1,MLCO    
       YY(I)=0.
      ENDDO

      DO 100 J=J1,J2
       VLIN=VLCO(J)
       SLIN=SLCO(J)*1E20
       ELIN=LCLSE(J)
       ALIN=LCWIDA(J)
       SBLIN=LCWIDS(J)
       TDW=LCTDEP(J)
       TDWS=TDW

       XX(J-J1+1)=VLIN


C      Stimulated emission coefficient.
       TS1 = (1.0 - DPEXP(-1.439*SNGL(VLIN)/TEMP))
       TS2 = (1.0 - DPEXP(-1.439*SNGL(VLIN)/296.0))
       TSTIM=1.0
       IF(TS2.NE.0.)TSTIM=TS1/TS2

       SLIN=SLIN*1E27
       LNABSCO=LOG(SLIN)+LOG(TCORS1)+TCORS2*ELIN+LOG(TSTIM)
       ABSCO=SNGL(EXP(LNABSCO))

C      AD is the Doppler-broadened line width
C      Y is the Lorentz/collision-broadened line width divided by
C      the Doppler-broadened line width.

       AD=TCORDW*SNGL(VLIN)
       Y = (ALIN*(1.-FRAC)*TRATIO**TDW+(ALIN-SBLIN)*FRAC*
     1  TRATIO**TDWS)*PRESS/AD    

       SUM=0.0
       DO I=0,NLCO   
        DV = I*LCOBINSIZE
        VV=VLIN+DV
        X = DV/AD

C       Find line contribution at centre
        WEIGHT(I)=SUBLINE(IDGAS,PRESS,TEMP,IPROC,VV,VLIN,
     1   ABSCO,X,Y,AD,FNH3,FH2,LLQ,DOUBV)
        IF(I.EQ.0)THEN
         SUM=SUM+WEIGHT(I)
        ELSE
         SUM=SUM+2*WEIGHT(I)
        ENDIF
       ENDDO

       DO I=0,NLCO
        WEIGHT(I)=WEIGHT(I)/SUM
       ENDDO

       I1=J-NLCO
       I2=J+NLCO
       IF(I1.LT.J1)I1=J1
       IF(I2.GT.J2)I2=J2
       DO I=I1,I2
        K=ABS(I-J)
        YY(I-J1+1)=YY(I-J1+1)+ABSCO*WEIGHT(K)
       ENDDO

100   CONTINUE

      DO 300 I=1,NBIN+1
        J = 1 + INT((VOUT(I)-XX(1))/LCOBINSIZE)
        F=(VOUT(I)-XX(J))/LCOBINSIZE
        YOUT(I)=(1.0-F)*YY(J)+F*YY(J+1)
C       DIVIDE STRENGTH BY BIN SIZE TO MAKE IT CONTINUUM
        YOUT(I)=YOUT(I)/LCOBINSIZE
C        print*,'Y',I,VOUT(I),J,F,YOUT(I)
300   CONTINUE

      RETURN

      END
