      SUBROUTINE NPARTSUM (TEMP)
C     *******************************************************************
C     Subroutine to calculation the partition function for the rotational
C     states of Hydrogen. For complete description, see:

C      Borysow,J., L. Trafton, L. Frommhold and G. Birnbaum, 'Modelling
C      of pressure-induced far-infrared absorption spectra: molecular 
C      hydrogen pairs', The Astrophysical Journal, vol. 296, p. 644--654,
C      (1985).
C
C     This code is described specifically on Page 653.
C 
C     Added multiple comments to original. 
C     Also modified to force the ortho/para ratio to a user-specified
C     value if NORMAL=1, instead of just the normal deep value 3:1
C
C 	Pat Irwin	11/7/01
C	Pat Irwin	2/3/12	Updated for Radtrans2.0
C
C     *******************************************************************
C
      IMPLICIT DOUBLE PRECISION(A-H,O-Z)      
      COMMON /H2PART1/ Q,WH2(2),B0,D0
      COMMON /H2PART2/ JRANGE1,NORMAL,F

C     NORMAL=1 ADJUSTS THE H2 STAT.WEIGHTS SO THAT THE ORTHO/PARA RATIO
C     EQUALS (1-F)/F:1. 
C     SET NORMAL=0 FOR EQUILIBRIUM HYDROGEN.

      DATA B0,D0/59.3392,0.04599/
C     B0,D0 are ROT.CONSTANTS
C     WH2 contains the degeneracy of the even (1.0) and odd (3.0) states.

C     Internal function EH2 calculates the energy of the
C     (N,I)th vibrational-rotational level.
      EH2(N,I)=4395.34*(DFLOAT(N)+.5)-117.905*(DFLOAT(N)+.5)**2
     2  +(60.809-2.993*(DFLOAT(N)+.5)+.025*(DFLOAT(N)+.5)**2)*
     2  DFLOAT(I)- (.04648-.00134*(DFLOAT(N)+.5))*DFLOAT(I*I)

C     Internal function PH2 calculates the density of states function
      PH2(J,T)=DFLOAT(2*J+1)*WH2(1+MOD(J,2))*DEXP(-1.4387859*
     1  EH2(0,J*(J+1)
     1)/T)

      WH2(1)=1.D0	! Degeneracy of even states
      WH2(2)=3.D0	! Degeneracy of odd states

C     Calculate the Rotational Partition Function Q. Terminate
C     when converged to within Q/900.0. Sum over successively higher
C     J-states
      Q=0.
      J=0
   10 DQ=PH2(J,TEMP)
      Q=Q+DQ
      J=J+1
      IF (DQ.GT.Q/900.) GO TO 10
      JRANGE1=J		! Maximum J-level needed in summing Q

      IF (NORMAL) 20,20,30
   20 CONTINUE
C     Come here if INORMAL = -1,0. Just return
      RETURN

C     Come here if INORMAL = 1 force para fraction to F
   30 J=-1
      S=0.			! Sum of all states
      SEV=0.			! Sum of even states only
   40 J=J+1
      DS=PH2(J,TEMP)
      S=S+DS
      SEV=SEV+DS
      J=J+1
      S=S+PH2(J,TEMP)
      IF (J.GT.JRANGE1) GO TO 50
      GO TO 40
   50 SODD=S-SEV

      RM = (1.0-F)/F		! Required ortho/para ratio 
      WH2(2)=WH2(2)*RM*SEV/(SODD)
      Q=SEV/F
      RETURN
      END
