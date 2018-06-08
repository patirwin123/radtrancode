      subroutine forwardnoglblL(runname,ispace,iscat,fwhm,ngeom,nav,
     1 wgeom,flat,nconv,vconv,angles,gasgiant,occult,
     2 lin,nvar,varident,varparam,jsurf,jalb,jxsc,jtan,jpre,jrad,
     3 jlogg,RADIUS,nx,xn,ifix,ny,yn,kk)
C     $Id:
C     **************************************************************
C     Subroutine to calculate a synthetic spectrum and KK-matrix using
C     FINITE DIFFERENCES. The routine is identical in operation to 
C     forwardavfovX.f but calculates the K-matrix using old-fashioned 
C     finite differences. Routine exists to check that forwardavfovX.f, 
C     using the internal gradients is operating correctly, and also for
C     scattering calculations.
C
C     Input variables:
C       runname(60)   character Name of run.
C       ispace           integer Indicates if wavelengths in vconv
C                               are in wavenumbers(0) or
C                               wavelengths (1)
C	iscat		integer 0=non-scattering
C				1=plane-parallel scattering
C				2=non-plane limb/near-limb scattering
C       fwhm            real    Desired FWHM of final spectrum
C       ngeom           integer Number of observation geometries included.
C       nav(mgeom)      integer         Number of synthetic spectra required
C                                       to simulate each FOV-averaged
C                                       measurement spectrum.
C       wgeom(mgeom,mav)real     Integration weights to use
C       flat(mgeom,mav)  real    Integration point latitudes
C       nconv(mgeom)    integer Number of convolution wavelengths
C       vconv(mgeom,mconv) real    Convolution wavelengths
C       angles(mgeom,mav,3) real    Observation angles
C       gasgiant        logical Indicates if planet is a gas giant
C       lin             integer indicates role of previous retrieval (if any)
C       nvar    integer Number of variable profiles (gas,T,aerosol)
C       varident(nvar,3) integer identity of constituent to retrieved and
C					parameterisation method
C       occult          integer Flag for indicating solar occultation
C       varparam(nvar,mparam) real Additional arameters constraining profile.
C       jsurf           integer Position of surface temperature element in
C                               xn (if included)
C	jalb		integer position of first surface albedo element in
C				xn (if included)
C	jxsc		integer position of first x-section element in
C				xn (if included)
C	jtan		integer position of tangent ht. correction element in
C				xn (if included)
C	jpre		integer position of tangent pressure element in
C				xn (if included)
C       jrad            integer position radius element in
C                               xn (if included)
C       jlogg           integer position surface gravity (log(g)) element in
C                               xn (if included)
C       nx              integer Number of elements in state vector
C       xn(mx)          real	State vector
C	ifix(mx)	integer	Vector indicating which elements of xn we
C				 need gradients for
C       ny      	integer Number of elements in measured spectra array
C
C     Output variables
C       yn(my)          real    Synthetic radiances
C       kk(my,mx)       real    dR/dx matrix
C
C     Pat Irwin	4/4/01		Original
C     Pat Irwin 17/10/03	Tidied for Nemesis
C     Pat Irwin 28/10/03	Modified from forward.f for testing 
C				   purposes
C
C     **************************************************************

      implicit none
      integer i,j,ispace,ulog,jpath
      parameter (ulog=17)
      integer ngeom,ioff,igeom,lin
      include '../radtran/includes/arrdef.f'
      include '../radtran/includes/gascom.f'
      include '../radtran/includes/planrad.f'
      include 'arraylen.f'
      real xlat,xref,dx,fh
      integer layint,inormal,iray,itype,nlayer,laytyp,iscat
      integer ix,ix1,iav,iptf,j1,ifix(mx)
      real interpem
      real calcout(maxout3),fwhm,planck_wave
      real gradients(maxout4)
      integer nx,nconv(mgeom),npath,ioff1,ioff2,nconv1
      real vconv(mgeom,mconv),wgeom(mgeom,mav),flat(mgeom,mav)
      real layht,tsurf,esurf,angles(mgeom,mav,3)
      real xn(mx),yn(my),kk(my,mx),ytmp(my),ystore(my)
      real x0,x1,wing,vrel,maxdv,delv
      real vconv1(mconv),RADIUS
      integer ny,jsurf,jalb,jxsc,jtan,jpre,nem,nav(mgeom)
      integer nphi,ipath,iconv,k,imie,imie1,jrad,jlogg
      integer nmu,isol,lowbc,nf,nf1,nx2,occult
      real dist,galb,sol_ang,emiss_ang,z_ang,aphi,vv,Grav
      parameter (Grav=6.672E-11)
      double precision mu(maxmu),wtmu(maxmu)
      character*100 runname,logname
      character*100 rdummy
      real xmap(maxv,maxgas+2+maxcon,maxpro)
      common /imiescat/imie1

      integer nvar,varident(mvar,3)
      real varparam(mvar,mparam)
      logical gasgiant
      real vem(maxsec),emissivity(maxsec)

      integer cellngas,cellid(maxgas),celliso(maxgas),icread
      real cellength,cellpress,celltemp,cellvmr(maxgas)
      common/celldat/icread,cellngas,cellid,celliso,cellvmr,cellength,
     1  cellpress,celltemp
      real stelrad,solwave(maxbin),solrad(maxbin)
      real solradius,solomeg,solar,xsol,pi,AU
      parameter (pi=3.1415927, AU=1.49597870e8)


      print*,'forwardnoglblL called'
      print*,'lin = ',lin


C     jradf and jloggf are passed via the planrad common block
      jradf=jrad
      jloggf=jlogg

      call setup(runname,gasgiant,nmu,mu,wtmu,isol,dist,lowbc,
     1 galb,nf1,nphi,layht,tsurf,nlayer,laytyp,layint)

      call file(runname,logname,'log')

      open(ulog,file=logname,status='unknown')

C     Initialise arrays
      do i=1,my
       yn(i)=0.0
       do j=1,mx
        kk(i,j)=0.0
       enddo
      enddo

      call setup(runname,gasgiant,nmu,mu,wtmu,isol,dist,lowbc,
     1 galb,nf1,nphi,layht,tsurf,nlayer,laytyp,layint)

      print*,'setup called OK'

      if(jsurf.gt.0)then
       tsurf = xn(jsurf)
      endif

      ioff = 0

      print*,'ngeom = ',ngeom
      do 100 igeom=1,ngeom
       print*,'ForwardnoglblL. Spectrum ',igeom,' of ',ngeom
       
       nconv1 = nconv(igeom)
       do 105 i=1,nconv1
        vconv1(i)=vconv(igeom,i)
105    continue

       if(nconv1.gt.1)call sort(nconv1,vconv1)


        do 110 iav=1,nav(igeom)

         sol_ang = angles(igeom,iav,1)
         emiss_ang = angles(igeom,iav,2)
         aphi = angles(igeom,iav,3)
         
         if(sol_ang.lt.emiss_ang) then
           z_ang = sol_ang
         else
           z_ang = emiss_ang
         endif

C        New bit to increase number of Fourier components depending on
C        miniumum zenith angle
         if(iscat.eq.1.and.z_ang.ge.0.0)then
           nf = int(30*z_ang/90.0)
C            nf=9
C            nf=0
C            nf=20
         else
           nf=nf1
         endif

         print*,'Angles : ',sol_ang,emiss_ang,aphi
         print*,'nf = ',nf
         xlat = flat(igeom,iav)

         nx2 = nx+1

         do 111 ix1=1,nx2

          ix = ix1-1

          print*,'forwardnoglbl, ix,nx = ',ix,nx

          if(ix.gt.0)then
            xref = xn(ix)
            dx = 0.05*xref
            if(dx.eq.0)dx = 0.1

            if(ix.eq.jtan)then
             if(emiss_ang.lt.0)then
               dx=1.0
             else
               goto 111
             endif
            endif
   
            if(ix.eq.jpre)then
             if(emiss_ang.lt.0)then
               dx=0.01*xref
             else
               goto 111
             endif
            endif            
           
            print*,ix,dx,xn(ix)                  
            xn(ix)=xn(ix)+dx
            print*,'XN',(xn(j),j=1,nx)
          endif
          if(jsurf.gt.0)then
           tsurf = xn(jsurf)
          endif


C         Check to see if this variable is unconstrained enough to bother
C         calculating its gradient.
          if(ix.gt.0.and.ifix(ix).eq.1)then
           xn(ix)=xref
           goto 111
          endif

C         If we're retrieving planet radius then add correction to reference
C         radius
C         N.B.radius2 is passed via the planrad common block.
          if(jrad.gt.0)then
           radius2 = xn(jrad) + radius
          else
           radius2 = radius
          endif

C         If we're retrieving surface gravity then modify the planet mass
C         N.B. mass2 is passed via the planrad common block. Assume xn(jlogg)
C         holds log_10(surface gravity in cm/s^2). Need factor of 1e-20 to convert
C         mass to units of 1e24 kg.
          if(jlogg.gt.0)then
           mass2 = 1e-20*10**(xn(jlogg))*(radius2**2)/Grav
          endif


         
C         Set up parameters for scattering cirsrad run.
          CALL READFLAGS(runname,INORMAL,IRAY,IH2O,ICH4,IO3,INH3,
     1     IPTF,IMIE)
          IMIE1=IMIE

          itype=11			! scloud11wave

          print*,'************** FORWARDNOGLBL ***********'
          print*,'******** INORMAL = ',INORMAL
          print*,'******** ITYPE = ',ITYPE


C         Set up all files for a direct cirsrad run
          call gsetrad(runname,iscat,nmu,mu,wtmu,isol,dist,
     1     lowbc,galb,nf,nconv1,vconv1,fwhm,ispace,gasgiant,
     2     layht,nlayer,laytyp,layint,sol_ang,emiss_ang,aphi,xlat,lin,
     3     nvar,varident,varparam,nx,xn,jalb,jxsc,jtan,jpre,tsurf,xmap)

C         If planet is not a gas giant and observation is not at limb then
C         we need to read in the surface emissivity spectrum
          if(.not.gasgiant.and.emiss_ang.ge.0)then
           call readsurfem(runname,nem,vem,emissivity)
          else
           nem=2
           vem(1)=-100.0
           vem(2)=1e7
           emissivity(1)=1.0
           emissivity(2)=1.0
          endif


          call file(runname,runname,'lbl')
          open(11,file=runname,status='old')
           print*,'LBL data read in'
           read(11,*)x0,x1,delv
           print*,'Total calculation range and step (cm-1) : ',
     1      x0,x1,delv
           read(11,*)wing,vrel,maxdv
           print*,'wing, vrel, maxdv : ',wing, vrel, maxdv
           if(maxdv.ne.vrel)then
            print*,'*Warning from forwardnoglbl.f: V_cutoff <> vrel.'
            print*,'*These should usually be set equal'
            print*,'V_cut_off = ',maxdv
            print*,'VREL = ',vrel
           endif 

          close(11)

          rdummy=runname
          call lblrtf_wave(x0, x1, wing, vrel, maxdv, rdummy, dist, 
     1     inormal, iray, delv, fwhm, ispace, npath, 
     2     vconv1, nconv1, itype,nem,vem,emissivity,tsurf, 
     3     calcout, IPTF)


C         Unless an SCR calculation, first path is assumed to be thermal emission
        
          if(occult.eq.2)then
C           just calculate transmission of path. Assumes no thermal emission into beam and no other nadir paths.
           do ipath=jpath,jpath+1
            fh=1.0-fh
            do j=1,nconv1
              iconv=-1
              do k=1,nconv1
               if(vconv(igeom,j).eq.vconv1(k))iconv=k
              enddo
              if(iconv.lt.0)then
               print*,'Error in forwardnoglbl iconv < 0'
               stop
              endif
              ioff1=nconv1*(ipath-1)+iconv
              ytmp(ioff+j)=calcout(ioff1)
            enddo

            if(ix.eq.0)then
             do j=1,nconv1
              yn(ioff+j)=yn(ioff+j)+wgeom(igeom,iav)*ytmp(ioff+j)
              ystore(ioff+j)=ytmp(ioff+j)
             enddo
            else
             do j=1,nconv1
              kk(ioff+j,ix)=kk(ioff+j,ix)+wgeom(igeom,iav)*
     1                (ytmp(ioff+j) - ystore(ioff+j))/dx
             enddo
             xn(ix)=xref
            endif
           enddo

          else

           
           do ipath=jpath,jpath+1
            fh=1.0-fh
            do j=1,nconv1
              iconv=-1
              do k=1,nconv1
               if(vconv(igeom,j).eq.vconv1(k))iconv=k
              enddo
              if(iconv.lt.0)then
               print*,'Error in forwardnoglbl iconv < 0'
               stop
              endif
              ioff1=nconv1*(ipath-1)+iconv
              ytmp(ioff+j)=calcout(ioff1)
            enddo

            if(ix.eq.0)then
             do j=1,nconv1
              yn(ioff+j)=yn(ioff+j)+wgeom(igeom,iav)*ytmp(ioff+j)
              ystore(ioff+j)=ytmp(ioff+j)
             enddo
            else
             do j=1,nconv1
              kk(ioff+j,ix)=kk(ioff+j,ix)+wgeom(igeom,iav)*
     1                (ytmp(ioff+j) - ystore(ioff+j))/dx
             enddo
             xn(ix)=xref
            endif
           enddo

           if(occult.eq.1.or.occult.eq.3)then
C           Add solar occultation radiance to thermal emission

            solradius = stelrad/(dist*AU)
            solomeg = pi*solradius**2


            do ipath=jpath+nlayer,jpath+nlayer+1
             fh=1.0-fh
             do j=1,nconv1
C             Get Solar irradiance
              CALL get_solar_wave(vconv1(j),dist,solar)
              xsol =  solar/solomeg
              iconv=-1
              do k=1,nconv1
               if(vconv(igeom,j).eq.vconv1(k))iconv=k
              enddo
              if(iconv.lt.0)then
               print*,'Error in forwardnoglbl iconv < 0'
               stop
              endif
              ioff1=nconv1*(ipath-1)+iconv
              ytmp(ioff+j)=calcout(ioff1)*xsol
             enddo

             if(ix.eq.0)then
              do j=1,nconv1
               yn(ioff+j)=yn(ioff+j)+wgeom(igeom,iav)*ytmp(ioff+j)
               ystore(ioff+j)=ytmp(ioff+j)
              enddo
             else
              do j=1,nconv1
               kk(ioff+j,ix)=kk(ioff+j,ix)+wgeom(igeom,iav)*
     1                (ytmp(ioff+j) - ystore(ioff+j))/dx*xsol
              enddo
              xn(ix)=xref
             endif

             if(occult.eq.3)then
C             divide thermal emission + solar occultation by solar radiance at top of atmosphere
              do j=1,nconv1
               CALL get_solar_wave(vconv1(j),dist,solar)
               xsol = solar/solomeg
               yn(ioff+j)=yn(ioff+j)/xsol
               kk(ioff+j,ix)=kk(ioff+j,ix)/xsol
              enddo
             endif
            enddo
           endif


          endif

111      continue
110     continue
     
       ioff = ioff + nconv1

100   continue

      close(ulog)

      return

      end
