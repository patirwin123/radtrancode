      SUBROUTINE QGAUS(FUNC,A,B,SS)
      DIMENSION X(5),W(5)
      DATA X/.1488743389,.4333953941,.6794095682,.8650633666,.9739065285
     */
      DATA W/.2955242247,.2692667193,.2190863625,.1494513491,.0666713443
     */
      XM=0.5*(B+A)
      XR=0.5*(B-A)
      SS=0
      DO 11 J=1,5
        DX=XR*X(J)
        SS=SS+W(J)*(FUNC(XM+DX)+FUNC(XM-DX))
11    CONTINUE
      SS=XR*SS
      RETURN
      END
