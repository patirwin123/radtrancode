      DOUBLE PRECISION FUNCTION DERF(X)
      DOUBLE PRECISION X,DGAMMP
      IF(X.LT.0.)THEN
        DERF=-DGAMMP(.5D0,X**2)
      ELSE
        DERF=DGAMMP(.5D0,X**2)
      ENDIF
      RETURN
      END
