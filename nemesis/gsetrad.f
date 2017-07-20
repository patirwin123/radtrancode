      subroutine gsetrad(runname,iscat,nmu,mu,wtmu,isol,dist,
     1 lowbc,galb,nf,nconv,vconv,fwhm,ispace,gasgiant,
     2 layht,nlayer,laytyp,layint,sol_ang,emiss_ang,aphi,xlat,lin,
     3 nvar,varident,varparam,nx,xn,jalb,jxsc,jtan,jpre,tsurf,xmap)
C     $Id:
C     ************************************************************************
C     Subroutine to write out the .pat, .prf, .xsc and .sca and aerosol 
C     files needed for a CIRSradg run. Routine also returns xmap
C     (calculated by subprofretg) which relates the functional
C     derivatives calculated by CIRSRADG to the state vector elements
C
C     Input variables
C       runname         character*100    Root run name.
C	iscat		integer		0=thermal emission	
C					1=plane parallel scattering 
C					2= limb/near-limb scattering 
C	nmu		integer		Number of zenith ordinates
C	mu(maxmu)	double pr.	Cos(zenith angles)
C	wtmu(maxmu)	double pr.	Quadrature weights
C	isol		integer		Sunlight on(1)/off(0)
C       dist            real            Solar distance (AU)
C       lowbc           integer         lower boundary condition
C       galb            real            ground albedo
C       nf              integer         Required number of Fourier components
C       nconv           integer         Number of calculation wavelengths
C       vconv(mconv)   	real            Calculation wavelength array
C	fwhm		real		FWHM of convolved spectrum
C	ispace		integer		0=cm-1, 1= wavelengths
C	gasgiant	logical		Indicates if planet is a gas giant
C	layht		real		Altitude of base layer (if non-limb,
C					this is set to -emiss_ang for limb
C					calculations)
C	nlayer		integer		Number of layers
C	laytyp		integer		How layers are separated
C	layint		integer		How layer amounts are integrated
C	sol_ang		real		Solar zenith angle
C	emiss_ang	real		Thermal emission angle
C	aphi		real		azimuth angle
C	xlat		real		latitude of observation
C	lin		integer		Integer to indicate role of previous
C                                       retrieval (if any)
C       nvar    	integer 	Number of variable profiles 
C					  (e.g. gas,T,aerosol)
C       varident(mvar,3) integer 	identity of constituent to retrieved
C					 and parameterisation
C       varparam(mvar,mparam) real 	Additional parameters constraining
C					  profile.
C	nx		integer		Number of elements in state vector
C	xn(mx)		real		state vector
C	jalb		integer		Position of surface albedo spectrum
C					in xn
C	jxsc		integer		Position of x-section spectrum
C					in xn
C	jtan		integer		Position of tangent height correction
C					in xn
C	jpre		integer		Position of tangent pressure
C					in xn
C	tsurf		real		Surface temperature
C
C    Output variables      
C	xmap(maxv,maxgas+2+maxcon,maxpro) real Mapping array relate
C		functional derivatives calculated by CIRSRADG to the
C		state vector elements
C	tsurf		real		Updated surface temperature (if
C					using previously retrieved value)
C
C     Pat Irwin	17/10/03	Modified from oxcirsg for Nemesis
C
C     ************************************************************************

      implicit none
      include '../radtran/includes/arrdef.f'
      include 'arraylen.f'

      integer max_mode, max_wave,iwave,imode
      parameter (max_mode = 10)
      parameter (max_wave = 1000)

      integer nconv,lin,ispace,ncont1,xflag,nwave,np,np1
      real xlat,fwhm,xlatx,tsurf,wave(max_wave)
      real xsec(max_mode,max_wave,2),nimag(max_wave)
      real nreal(max_wave),r0,v0,clen,k2(mx)
      real srefind(max_wave,2),parm(3),rs(3),vm,nm
      real v1(max_wave),k1(max_wave),vm1,n1(max_wave)
      integer nlayer,laytyp,iscat,nx,nxx,ncont,nx1
      integer layint,iprfcheck,check_profile,nmode,inorm
      real layht,xod(maxcon),xscal(maxcon),cwid,pmeth
      real vconv(mconv),minlam,lambda0
      integer nmu,isol,lowbc,nf,flagh2p,jalb,jxsc,jtan,jpre
      integer jsurfx,jalbx,jxscx,jtanx,jprex,nprox,icheck,icont
      integer jradx,npvar,jloggx,npro,nvmr,ierr,ierrx,nxsc
      real x,y
      double precision mu(maxmu),wtmu(maxmu)
      real dist,galb,xn(mx),xnx(mx),aphi,emiss_ang,sol_ang
      real stx(mx,mx),xdnu,xtest
      real xmap(maxv,maxgas+2+maxcon,maxpro)
      real xmapx(maxv,maxgas+2+maxcon,maxpro)
      integer jpara
      character*100 runname,buffer,aname

      integer nvar,ivar,varident(mvar,3),i,j,nalb,nalb1
      real varparam(mvar,mparam),alb(maxsec),valb(maxsec)
      integer nvarx,varidentx(mvar,3),ivarx,iflagsrom,iflagtest,iflagcb
      real varparamx(mvar,mparam),od1,xsc(maxsec,maxgas)
      real ssa(maxsec,maxgas)
      logical gasgiant,iflagcloud,cbflag
      integer NN,NDUST
      REAL DUSTH(MAXLAY),DUST(MAXCON,MAXLAY)

      integer mcloud,ncloud,bcloud
      parameter (mcloud=10)
      real cpbot(mcloud),cptop(mcloud),codepth(mcloud),cfsh(mcloud)
      integer nlaycloud(mcloud)
      real cbpbot(mcloud),cbptop(mcloud),cbodepth(mcloud),cbfsh(mcloud)
      integer ncblaycloud(mcloud)

      real csx,nrealfix(mx),nimagfix(mx)
      integer fixtoggle
      common /maltmieser/nrealfix,nimagfix

     
      print*,'gsetrad, lin = ',lin

C     Look to see if the CIA file refined has variable para-H2 or not.
      call file(runname,runname,'cia')

      open(12,FILE=runname,STATUS='OLD')
       read(12,1) aname
       read(12,*) xdnu
       read(12,*) jpara
      close(12)

      flagh2p=0
      if(jpara.ne.0)then
       flagh2p=1
      endif

      xflag=0
      call subprofretg(xflag,runname,ispace,iscat,gasgiant,xlat,
     1  nvar,varident,varparam,nx,xn,jpre,ncont,flagh2p,xmap,ierr)

      if(lin.eq.1.or.lin.eq.3)then
       call readxtmp(runname,xlatx,nvarx,varidentx,varparamx,nprox,
     1  nxx,xnx,stx,jsurfx,jalbx,jxscx,jtanx,jprex,jradx,jloggx)

       call stripvar(nvarx,varidentx,varparamx,nprox,nvar,varident,
     1  nxx,xnx)
      
       xflag=1
       call subprofretg(xflag,runname,ispace,iscat,gasgiant,xlat,
     1  nvarx,varidentx,varparamx,nxx,xnx,jprex,ncont,flagh2p,xmapx,
     2  ierrx)

       do ivarx = 1,nvarx


        if(varidentx(ivarx,1).eq.887)then

C        ********* Adjust cloud cross-section spectrum  **********
         nxsc = int(varparamx(ivarx,1))
         icont = int(varparamx(ivarx,2))
         call file(runname,runname,'rxs')
         open(9,file=runname,status='old')
51       read(9,1)buffer
         if(buffer(1:1).eq.'#')goto 51
         read(buffer,*)ncont1
         if(ncont1.ne.ncont)then
          print*,'Error in gsetrad ncont1 <> ncont'
          print*,ncont1,ncont
          print*,'file : ',runname
         endif

         do i=1,nxsc
          read(9,*)valb(i),(xsc(i,j),j=1,ncont)
          read(9,*)(ssa(i,j),j=1,ncont)
         enddo
         close(9)

         call file(runname,runname,'xsc')
         open(9,file=runname,status='unknown')
         write(9,*)ncont
         do i=1,nxsc
          xsc(i,icont)=exp(xnx(jxscx+i-1))
          write(9,*)valb(i),(xsc(i,j),j=1,ncont)
          write(9,*)(ssa(i,j),j=1,ncont)
         enddo
         close(9)

        endif


        if(varidentx(ivarx,1).eq.888)then

C        ********* reset surface albedo spectrum  **********
         nalb = int(varparamx(ivarx,1))
         call file(runname,runname,'rsu')
         open(9,file=runname,status='old')
54       read(9,1)buffer
         if(buffer(1:1).eq.'#')goto 54
         read(buffer,*)nalb1
         if(nalb1.ne.nalb)then
          print*,'Error in gsetrad nalbx <> nalb1'
          print*,nalb,nalb1
          print*,'file : ',runname
         endif

         do i=1,nalb
          read(9,*)valb(i),alb(i)
         enddo
         close(9)

         call file(runname,runname,'sur')
         open(9,file=runname,status='unknown')
         write(9,*)nalb
         do i=1,nalb
          xtest = 1.-exp(xnx(jalbx+i-1))
C         Stop emissivity going negative
          if(xtest.lt.0.0)xtest=0.
          write(9,*)valb(i),xtest
         enddo
         close(9)

        endif



        if(varidentx(ivarx,1).eq.889)then

C        ********* reset surface albedo scaling  **********
         call file(runname,runname,'rsu')
         open(9,file=runname,status='old')
57       read(9,1)buffer
         if(buffer(1:1).eq.'#')goto 57
         read(buffer,*)nalb
         do i=1,nalb
          read(9,*)valb(i),alb(i)
         enddo
         close(9)

         call file(runname,runname,'sur')
         open(9,file=runname,status='unknown')
         write(9,*)nalb
         do i=1,nalb
          xtest = 1.0 - (1.-alb(i))*exp(xnx(jalbx))
C         Stop emissivity going negative
          if(xtest.lt.0.0)xtest=0.
          write(9,*)valb(i),xtest
         enddo
         close(9)

        endif

        

        if(varidentx(ivarx,1).eq.777)then
C       ************ reset tangent heights   ***********
         if(emiss_ang.gt.0)then
          print*,'Can not do tangent ht correction for non-limb case'
         else 
          sol_ang = sol_ang+xnx(jtanx)
         endif

        endif

        if(varidentx(ivarx,1).eq.999)then
C       ***************** Surface temperature correction ***********
         tsurf = xnx(jsurfx)
        endif

       enddo

      endif

      iflagcloud=.false.
      cbflag=.false.
      iflagsrom=0
      iflagcb=0

      do ivar=1,nvar

       print*,'gsetrad - ',ivar,varident(ivar,1)


       if(varident(ivar,1).eq.887)then

C        ********* Adjust cloud cross-section spectrum  **********
         nxsc = int(varparam(ivar,1))
         icont = int(varparam(ivar,2))
         call file(runname,runname,'rxsc')
         open(9,file=runname,status='old')
52       read(9,1)buffer
         if(buffer(1:1).eq.'#')goto 52
         read(buffer,*)ncont1
         if(ncont1.ne.ncont)then
          print*,'Error in gsetrad ncont1 <> ncont'
          print*,ncont1,ncont
          print*,'file : ',runname
         endif

         do i=1,nxsc
          read(9,*)valb(i),(xsc(i,j),j=1,ncont)
          read(9,*)(ssa(i,j),j=1,ncont)
         enddo
         close(9)

         call file(runname,runname,'xsc')
         open(9,file=runname,status='unknown')
         write(9,*)ncont
         do i=1,nxsc
          xsc(i,icont)=exp(xn(jxsc+i-1))
          write(9,*)valb(i),(xsc(i,j),j=1,ncont)
          write(9,*)(ssa(i,j),j=1,ncont)
         enddo
         close(9)

       endif



       if (varident(ivar,1).eq.888)then
C       ********* surface albedo spectrum retrieval **********
        nalb = int(varparam(ivar,1))
        call file(runname,runname,'rsu')
        open(9,file=runname,status='old')
55      read(9,1)buffer
        if(buffer(1:1).eq.'#')goto 55
        read(buffer,*)nalb1
        if(nalb1.ne.nalb)then
         print*,'Error in gsetrad nalb <> nalb1'
         print*,nalb,nalb1
         print*,'file : ',runname
        endif

        do i=1,nalb
         read(9,*)valb(i),alb(i)
        enddo
        close(9)

        call file(runname,runname,'sur')
        open(9,file=runname,status='unknown')
        write(9,*)nalb
        do i=1,nalb
         xtest = 1.-exp(xn(jalb+i-1))
C        Stop emissivity going negative
         if(xtest.lt.0.0)xtest=0.0
         write(9,*)valb(i),xtest
        enddo
        close(9)

       endif



       if (varident(ivar,1).eq.889)then
C       ********* surface albedo spectrum multiplier retrieval **********
        call file(runname,runname,'rsu')
        open(9,file=runname,status='old')
58      read(9,1)buffer
        if(buffer(1:1).eq.'#')goto 58
        read(buffer,*)nalb
        do i=1,nalb
         read(9,*)valb(i),alb(i)
        enddo
        close(9)

        call file(runname,runname,'sur')
        open(9,file=runname,status='unknown')
        write(9,*)nalb
        do i=1,nalb
         xtest = 1.0 - (1.-alb(i))*exp(xn(jalb))
C        Stop emissivity going negative
         if(xtest.lt.0.0)xtest=0.0
         write(9,*)valb(i),xtest
        enddo
        close(9)

       endif

       if(varident(ivar,1).eq.777)then
C      ***************** Tangent height correction ***********
        if(emiss_ang.gt.0)then
         print*,'Can not do tangent ht correction for non-limb case'
        else
         sol_ang = sol_ang+xn(jtan)
        endif

       endif

C      Make sure laytyp and nlayer consistent for varident(ivar,3)=25 model
       if(varident(ivar,3).eq.25)then
        if(laytyp.ne.4)then
         print*,'Error gsetrad: laytyp =/= 4'
         print*,'Need to set laytyp=4 in jupiter.set'
         print*,'to use varident(ivar,3)=25 model'
         stop
        endif
        if(nlayer.ne.varparam(ivar,2))then
         print*,'Error gsetrad:'
         print*,'nlayer in jupiter.set =/= nlayer in jupiter.apr'
         stop
        endif
       endif

       iflagtest=varident(ivar,1)
       if(iflagtest.ge.222.and.iflagtest.le.226)then
        iflagcloud=.true.
        iflagsrom=iflagtest
       else
        if(iflagtest.eq.227)then!flag if creme brulee model
         cbflag=.true.
         iflagcb=iflagtest
         print*,'iflagtest = ',iflagtest
        endif
       endif

      enddo

C     See if Sromovsky cloud layer model is specified.
      print*,'gsetrad - iflagcloud,iflagsrom = ',iflagcloud,iflagsrom
      print*,'gsetrad - cbflag, iflagcb = ',cbflag,iflagcb

      if(iflagcloud)then

        if(iflagsrom.ne.226)then
         call extractsrom(runname,iflagsrom,nvar,varident,
     1    varparam,nx,xn,ncloud,cpbot,cptop,nlaycloud,codepth,
     2    cfsh,cwid,pmeth)
        else
         call extracttwocloud(runname,iflagsrom,nvar,varident,
     1    varparam,nx,xn,ncloud,cpbot,cptop,nlaycloud,codepth,
     2    cfsh)
        endif 
        
       print*,'Calling gwritepatsrom - ncloud = ',ncloud
       call gwritepatsrom(runname,gasgiant,iscat,sol_ang,
     1  emiss_ang,nconv,vconv,fwhm,layht,nlayer,
     2  laytyp,layint,flagh2p,ncloud,cpbot,cptop,nlaycloud,
     3  codepth,cfsh,iflagsrom,cwid,pmeth)

      elseif(cbflag)then!see if creme brulee model is specified
        call extractcb(runname,iflagcb,nvar,varident,
     1    varparam,xn,ncloud,cbpbot,cbptop,ncblaycloud,cbodepth,
     2    cbfsh)
          
       print*,'Calling gwritepatcb'
       call gwritepatcb(runname,gasgiant,iscat,sol_ang,
     1  emiss_ang,nconv,vconv,fwhm,layht,nlayer,
     2  laytyp,layint,flagh2p,ncloud,cbpbot,cbptop,ncblaycloud,
     3  cbodepth,cbfsh,iflagcb)

      else

       call gwritepat(runname,gasgiant,iscat,sol_ang,
     1  emiss_ang,nconv,vconv,fwhm,layht,nlayer,
     2  laytyp,layint,flagh2p)

      endif

      call mod_scatter(runname,ncont,nmu,mu,wtmu,isol,dist,lowbc,
     1 galb,nf,sol_ang,emiss_ang,aphi)


      icheck=0
      do ivar=1,nvar
       if(varident(ivar,3).eq.9.or.varident(ivar,3).eq.10)icheck=1
       if(varident(ivar,3).eq.14.or.varident(ivar,3).eq.15)icheck=1
       if(varident(ivar,3).eq.8)icheck=1
      enddo


C     Check to see if anything bad has happened in the .prf file before 
C     running subpath
      iprfcheck=check_profile(runname)
     
C     Compute the drv file to get the aerosol optical depths
      if(icheck.eq.1.and.iprfcheck.eq.0) then

        call subpath(runname)

        call readdustod(runname,ncont1,xod)
       
        do i=1,ncont1
         xscal(i)=1.0
        enddo

        open(12,file='aerosol.prf',status='old')
56       READ(12,1)BUFFER     
1        FORMAT(A)
         IF(BUFFER(1:1).EQ.'#') GOTO 56
         READ(BUFFER,*)NN,NDUST
         DO 105 J=1,NN
           READ(12,*)DUSTH(J),(DUST(I,J),I=1,NDUST)
105      CONTINUE
        close(12)

        nx1=0

        do ivar=1,nvar
         print*,'ivar = ',ivar
         if(varident(ivar,1).le.100)then

          if(varident(ivar,3).eq.9.or.varident(ivar,3).eq.21.
     1 or.varident(ivar,3).eq.8)then
              icont=abs(varident(ivar,1))
              od1=exp(xn(nx1+1))
              xscal(icont)=xod(icont)/od1
              print*,icont,xod(icont),od1
              do j=1,NN
               dust(icont,j)=dust(icont,j)/xscal(icont)
              enddo
          endif
          if(varident(ivar,3).eq.10)then
              icont=int(varparam(ivar,1))
              od1=exp(xn(nx1+3))
              xscal(icont)=xod(icont)/od1

              do j=1,NN
               dust(icont,j)=dust(icont,j)/xscal(icont)
              enddo
          endif
          if(varident(ivar,3).eq.14.or.varident(ivar,3).eq.15)then
              icont=abs(varident(ivar,1))
              od1=exp(xn(nx1+1))
              xscal(icont)=xod(icont)/od1
              print*,'gsetrad - icont,od1,xscal(icont) = ',icont,
     1          od1,xscal(icont)

              do j=1,NN
               dust(icont,j)=dust(icont,j)/xscal(icont)
              enddo
          endif

          np = npvar(varident(ivar,3),NN,varparam(ivar,1))

         else

          np=1
          if(varident(ivar,1).eq.888)np = int(varparam(ivar,1))
          if(varident(ivar,1).eq.887)np = int(varparam(ivar,1))
          if(varident(ivar,1).eq.444)np = 2+int(varparam(ivar,1))
          if(varident(ivar,1).eq.445)np = 3+int(varparam(ivar,1))
          if(varident(ivar,1).eq.222)np = 8
          if(varident(ivar,1).eq.223)np = 9
          if(varident(ivar,1).eq.224)np = 9
          if(varident(ivar,1).eq.225)np = 11
          if(varident(ivar,1).eq.226)np = 8
          if(varident(ivar,1).eq.227)np = 7

         endif

         nx1=nx1+np

        enddo


        print*,'Writing out scale aerosol'
        open(12,file='aerosol.prf',status='unknown')
         BUFFER='# simple.prf'
         WRITE(12,1)BUFFER     
         WRITE(12,*)NN,NDUST
         DO 106 J=1,NN
           WRITE(12,*)DUSTH(J),(DUST(I,J),I=1,NDUST)
C           print*,DUSTH(J),(DUST(I,J),I=1,NDUST)
106      CONTINUE
        close(12)

C       check that rescaling has happened correctly
        call subpath(runname)

      endif

      nx1=0
      CALL readrefhead(runname,npro,nvmr,gasgiant)

      do ivar=1,nvar

       np=1
       if(varident(ivar,1).le.100)then
           np=npvar(varident(ivar,3),npro,varparam(ivar,1))
       endif
       if(varident(ivar,1).eq.888)np = int(varparam(ivar,1))
       if(varident(ivar,1).eq.887)np = int(varparam(ivar,1))
       if(varident(ivar,1).eq.222)np = 8
       if(varident(ivar,1).eq.223)np = 9
       if(varident(ivar,1).eq.224)np = 9
       if(varident(ivar,1).eq.225)np = 11
       if(varident(ivar,1).eq.226)np = 8
       if(varident(ivar,1).eq.227)np = 7
          

       if(varident(ivar,1).eq.444.or.varident(ivar,1).eq.445)then

           iwave=ispace
           if(iwave.eq.0)iwave=2

           imode=varident(ivar,2)

           r0 = exp(xn(nx1+1))
           v0 = exp(xn(nx1+2))
           if(varident(ivar,1).eq.445)then
            csx = exp(xn(nx1+3))
           else
            csx = -1.0
           endif
           np1 = int(varparam(ivar,1))
           clen = varparam(ivar,2)           
           vm = varparam(ivar,3)
           nm = varparam(ivar,4)
           lambda0 = varparam(ivar,5)
           fixtoggle = varparam(ivar,6)

           call get_xsecA(runname,nmode,nwave,wave,xsec)

C          np1 should now match nwave
           if(np1.ne.nwave)then
             print*,'Warning from gsetrad.f, nwave in refindex file is'
             print*,'different from that in .xsc file.'
           endif
           do i=1,nwave
            if(varident(ivar,1).eq.445)then
             nimag(i)=exp(xn(nx1+3+i))
            else
             nimag(i)=exp(xn(nx1+2+i))
            endif
           enddo

C          Compute nreal from KK
           if(ispace.eq.0)then
C           nimag in wavenumber space, can transfer directly
            do i=1,nwave
             v1(i)=wave(i)
             k1(i)=nimag(i)
             vm1=vm
            enddo
           else
C          If nimag is in wavelength space, need to convert to wavenumbers
            do i=1,nwave
             v1(i)=1e4/wave(nwave+1-i)
             k1(i)=nimag(nwave+1-i)
             vm1=1e4/vm
            enddo
           endif

           call kk_new_sub(nwave,v1,k1,vm1,nm,n1)

           
           buffer='refindexN.dat' 
           buffer(9:9)=char(ivar+48)
           open(12,file=buffer,status='unknown')

           if(ispace.eq.0)then
            do i=1,nwave
             nreal(i)=n1(i)
            enddo
           else
            do i=1,nwave
             nreal(i)=n1(nwave+1-i)
            enddo
           endif

           inorm=1
           iscat=1
C          Find minimum wavelength
           if(ispace.eq.0)then
            minlam=1e4/wave(nwave)
           else
            minlam=wave(1)
           endif

           do i=1,nwave
            srefind(i,1)=nreal(i)
            srefind(i,2)=nimag(i)
	    if(varident(ivar,1).eq.445)then
	     write(12,*)wave(i),nreal(i),nimag(i),
     1                  nrealfix(i),nimagfix(i)
	    else
             write(12,*)wave(i),nreal(i),nimag(i)
	    endif
           enddo
           close(12)

           parm(1)=r0
           parm(2)=v0
           parm(3)=(1. - 3 * parm(2))/parm(2)

           rs(1)=0.015*minlam
           rs(2)=0.
           rs(3)=rs(1)

           call modmakephase(iwave,imode,inorm,iscat,
     1   parm,rs,srefind,runname,lambda0,csx,
     2   nrealfix,nimagfix,fixtoggle)

           if(varident(ivar,1).eq.445)then
            np=3+np1
           else
            np=2+np1
           endif

       endif

       nx1=nx1+np

      enddo

      return

      end
    
