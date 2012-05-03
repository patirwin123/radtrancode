      SUBROUTINE cirsrtfg_wave(runname,dist,inormal,iray,fwhm1,
     1 ispace,vwave,nwave,itype1, nem, vem, emissivity,tsurf,gtsurf,
     2 nv,xmap,vconv,nconv,npath1,calcout,gradients)
C***********************************************************************
C_TITL:	CIRSRTFG_WAVE.f
C
C_DESC: 
C
C_ARGS:	Input variables:
C	runname		CHARA*100 Operation filename.
C	dist		REAL	Distance from Sun in units of AU.
C	inormal		INT	Flag for ortho:para ratio (0=equilibrium
C				=>1:1) (1=normal =>3:1).
C	fwhm1		REAL	Full-Width-at-Half-Max.
C       ispace          integer Indicates if wavelengths in vconv and
C				vwave are in wavenumbers(0) or 
C				wavelengths (1)
C	vwave(nwave)	REAL	Calculation wavenumbers.
C	nwave		INT	Number of calculation wavenumbers.
C	itype1		INT	Value designating the chosen scattering
C				routine (currently only scloud8 through
C				scloud11).
C	nv		INT	Number of 'on'/variable elements.
C	xmap(maxv,maxgas+2+maxcon,maxpro)	...
C			REAL	Matrix giving rate of change of elements
C				of T/P and aerosol .prf values with each
C				of the NV variables.
C	vconv(nconv)	REAL	Convolution wavenumbers.
C	nconv		INT	Number of convolution wavenumbers.
C	npath1		INT	Number of paths in calculation.
C
C
C	Output variables:
C	calcout(maxout3) REAL	Output values at each wavenumber for each
C				output type for each path
C	gradients(maxout4) REAL	Calculate rate of change of output with 
C				each of the NV variable elements, for
C				each wavenumber and for each path.
C
C_FILE:	unit=4		dump.out
C
C_CALL:	SUBPATHG	Reads in the .pat file, computes the atmospheric
C			absorber paths, then outputs the .drv file.
C	FILE		Forces file extension.
C	READ_KLIST	Reads in correlated-k files from .kls, passes
C			variables to common block INTERPK.
C	GET_SCATTER	Reads in scattering files (e.g. .sca).
C	GET_XSEC	Reads in cross-sections (.xsc) file.
C	CIRSRADG
C	MAP2PRO		Converts the rate of change of output with respect
C			to layer properties to the rate of change of
C			output with .prf properties.
C	MAP2XVEC	Converts from rate of change of radiance with
C			profile .prf properties to user defined variables.
C	CIRSCONV	Convolves input spectrum with a bin of width
C			fwhm to produce an output spectrum.
C	CLOSE_SCAT	Closes any opened scattering files before next
C			iteration of retrieval algorithm.
C
C_HIST: 
C	30.7.2001 PGJI  Serious modification to deal with gradients.
C	7aug03	NT	corrected: inormal, real->integer and 
C			fwhm1, integer -> real. so consistent with other routines
C	29.2.2012 PGJI	Updated for Radtrans2.0
C
C***************************** VARIABLES *******************************

      IMPLICIT NONE

      INCLUDE '../includes/arrdef.f'
C     ../includes/arrdef.f defines the maximum values for a series of variables
C     (layers, bins, paths, etc.)
      INCLUDE '../includes/pathcom.f'
C     ../includes/pathcom.f holds the variables used by the software when 
C     calculating atmospheric paths (e.g. FWHM, IMOD, NPATH and LINKEY).
      INCLUDE '../includes/laycom.f'
C     ../includes/laycom.f holds variables used only by the path software
C     parameters are passed between routines mostly using common blocks
C     because of the extensive use of large arrays. NOTE: laycom uses
C     parameters defined in pathcom.
      INCLUDE '../includes/laygrad.f'
C     ../includes/laygrad.f holds the variables for use in gradient 
C     calculations.

      INTEGER iparam,ipro,ntab1,ntab2
C     NTAB1: = NPATH*NWAVE, must be less than maxout3
C     NTAB2: = NPATH*NWAVE*NV, must be less than maxout4.
      INTEGER nwave,i,j,nparam,jj,icont,nconv

      INTEGER itype1,npath1,ispace,nem
      REAL fwhm1,vem(maxsec),emissivity(maxsec),tsurf,gtsurf
      REAL RADIUS1,RADIUS2
C     NB: The variables above have the added '1' to differentiate the 
C     variables passed into this code from that defined in
C     ../includes/pathcom.f. The definitions are explained above.

      REAL dist,xref,xcomp
      INTEGER inormal,iray
C     XREF: % complete
C     XCOMP: % complete printed in increments of 10.
      REAL vwave(nwave),output(maxpat),vconv(nconv)
      REAL doutputdq(maxpat,maxlay,maxgas+2+maxcon)
      REAL doutmoddq(maxpat,maxgas+2+maxcon,maxpro)
      REAL doutdx(maxpat,maxv)
      REAL tempout(maxout3),tgrad(maxout4)
      REAL calcout(maxout3),gradients(maxout4)
      REAL xmap(maxv,maxgas+2+maxcon,maxpro)
      REAL y(maxout),yout(maxout),vv
      CHARACTER*100 drvfil,radfile,xscfil,runname
      CHARACTER*100 klist,solfile,solname
      INTEGER iwave,ipath,k,igas,ioff1,ioff2,iv,nv
      INTEGER nsw,isw(maxgas+2+maxcon),iswitch
      LOGICAL scatterf,dustf,solexist

C     Need simple way of passing planetary radius to nemesis/forwarddisc
      COMMON /PLANRAD/RADIUS2
C     ************************* CODE ***********************


C Call subpathg to create layers, paths and the driver file.
      CALL subpathg(runname)
      npath1 = npath           ! npath is initilised in subpathg, set to
                               ! npath1 here so that it can be passed out

C Read the ktables.
      CALL file (runname, klist, 'kls')
      WRITE(*,1050)klist

      CALL read_klist(klist,ngas,idgas,isogas,nwave,vwave)

C Now read the scattering files if required.
      scatterf = .FALSE.
      DO I=1,npath
        IF(imod(I).EQ.15.OR.imod(I).EQ.16)scatterf = .TRUE.
      ENDDO

      IF(scatterf)THEN
        CALL file(runname, radfile, 'sca')
        CALL get_scatter(radfile,ncont)
      ENDIF

C ... and the xsc files likewise.
      dustf = .FALSE.
      IF(ncont.GT.0)dustf = .TRUE.

      IF(dustf)THEN
        CALL file(runname, xscfil, 'xsc')
        CALL get_xsec(xscfil, ncont)
      ENDIF

C     See if there is a solar or stellar reference spectrum and read in 
C     if present.

      call file(runname,solfile,'sol')

      inquire(file=solfile,exist=solexist)

      if(solexist)then
         call opensol(solfile,solname)
         CALL init_solar_wave(ispace,solname)
      endif


      PRINT*,'NPATH = ',NPATH

C=======================================================================
C
C	Call CIRSradg_wave.	
C
C=======================================================================

      nparam = ngas + 1 + ncont
      IF(flagh2p.EQ.1)nparam = nparam + 1

C Assess for which parameters a dr/dx value is actually needed
      nsw = 0
      DO iparam=1,nparam
        iswitch = 0
        DO iv=1,nv
          DO ipro=1,npro
            IF(xmap(iv,iparam,ipro).NE.0.0)iswitch = 1
          ENDDO
        ENDDO
        IF(iswitch.EQ.1)THEN
          nsw = nsw + 1
          isw(nsw) = iparam
        ENDIF
      ENDDO

      ntab1 = nwave*npath
      ntab2 = nwave*npath*nv
      IF(ntab1.GT.maxout3)THEN
        WRITE(*,*)'CIRSRTFG_WAVE.f :: Error: nwave*npath > maxout3'
        WRITE(*,*)'Stopping program.'
        WRITE(*,*)' '
        WRITE(*,*)'nwave*npath = ',ntab1,' maxout = ',maxout3
        STOP
      ENDIF
      IF(ntab2.GT.maxout4)THEN
        WRITE(*,*)'CIRSRTFG_WAVE.f :: Error: nwave*npath*nv > maxout4'
        WRITE(*,*)'Stopping program.'
        WRITE(*,*)' '
        WRITE(*,*)'nwave*npath*nv = ',ntab2,' maxout4 = ',maxout4
        STOP
      ENDIF

C Determine the % complete ...
      WRITE(*,*)' '
      WRITE(*,*)' Waiting for CIRSradg etal to complete ...'
      xcomp = 0.0
      DO 1000 iwave=1,nwave
        if(nwave.gt.1)then
          xref = 100.0*FLOAT(iwave - 1)/FLOAT(nwave - 1)
        else
          xref = 0.0
        endif
        IF(xref.GE.xcomp)THEN
          WRITE(*,*)' Percent Complete = ',xcomp
          xcomp = xcomp + 10.0
        ENDIF

        vv = vwave(iwave)

C       Pass radius of planet in units of cm for secondary transit 
C       calculations
        RADIUS1=RADIUS*1e5
        RADIUS2=RADIUS1
        CALL cirsradg_wave (dist,inormal,iray,delh,nlayer,npath,ngas,
     1  press,temp,pp,amount,iwave,ispace,vv,nlayin,
     2  layinc,cont,scale,imod,idgas,isogas,emtemp,itype1,
     3  nem, vem, emissivity, tsurf, gtsurf, RADIUS1,
     4  flagh2p,hfp,nsw,isw,output,doutputdq)


C Convert from rates of change with respect to layer variables to rates
C of change of .prf profile variables.
        CALL map2pro(nparam,doutputdq,doutmoddq)


C Convert from rates of change of .prf profile variables to rates of
C change of desired variables.
        CALL map2xvec(nparam,npro,npath,nv,xmap,doutmoddq,doutdx)


        DO ipath=1,npath
          ioff1 = nwave*(ipath - 1) + iwave
          tempout(ioff1) = output(ipath)
          DO iv=1,nv
            ioff2 = nwave*nv*(ipath - 1) + (iv - 1)*nwave + iwave
            tgrad(ioff2) = doutdx(ipath,iv)
          ENDDO
        ENDDO
1000  CONTINUE

C Convolve output calculation spectra with a square bin of width FWHM to
C get convoluted spectra.
      DO ipath=1,npath
        DO iwave=1,nwave
           ioff1 = nwave*(ipath - 1) + iwave
           y(iwave) = tempout(ioff1)
        ENDDO
		
        CALL cirsconv(runname,fwhm1,nwave,vwave,y,nconv,vconv,yout)
		
        DO iconv=1,nconv
          ioff1 = nconv*(ipath - 1) + iconv
          calcout(ioff1) = yout(iconv)
        ENDDO

        DO iv=1,nv
          DO iwave=1,nwave
            ioff2 = nwave*nv*(ipath - 1) + (iv - 1)*nwave + iwave
            y(iwave) = tgrad(ioff2)
          ENDDO

          CALL cirsconv(runname,fwhm1,nwave,vwave,y,nconv,vconv,yout)

          DO iconv=1,nconv
            ioff2 = nconv*nv*(ipath - 1) + (iv - 1)*nconv + iconv
            gradients(ioff2) = yout(iconv)
          ENDDO
        ENDDO
      ENDDO

C=======================================================================
C
C	Wrap up: formats, return, and end.
C
C=======================================================================

      CALL close_scat(ncont)

1050  FORMAT (/'Klist filename: ', A)

      RETURN

      END
