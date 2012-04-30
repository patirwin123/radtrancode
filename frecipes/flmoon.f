      SUBROUTINE FLMOON(N,NPH,JD,FRAC)
      PARAMETER (RAD=0.017453293)
      C=N+NPH/4.
      T=C/1236.85
      T2=T**2
      AS=359.2242+29.105356*C
      AM=306.0253+385.816918*C+0.010730*T2
      JD=2415020+28*N+7*NPH
      XTRA=0.75933+1.53058868*C+(1.178E-4-1.55E-7*T)*T2
      IF(NPH.EQ.0.OR.NPH.EQ.2)THEN
        XTRA=XTRA+(0.1734-3.93E-4*T)*SIN(RAD*AS)-0.4068*SIN(RAD*AM)
      ELSE IF(NPH.EQ.1.OR.NPH.EQ.3)THEN
        XTRA=XTRA+(0.1721-4.E-4*T)*SIN(RAD*AS)-0.6280*SIN(RAD*AM)
      ELSE
        PAUSE 'NPH is unknown.'
      ENDIF
      IF(XTRA.GE.0.)THEN
        I=INT(XTRA)
      ELSE
        I=INT(XTRA-1.)
      ENDIF
      JD=JD+I
      FRAC=XTRA-I
      RETURN
      END
