      program isotable
C ====================== Rationale ===============================
C
C Program to create a look-up table of pressure-induced absorption
C co-efficients at a range of temperatures and wavenumbers for
C H2 and He gas-pairs. Program runs a series of sub-programs
C to calculate the opacities for each gas. Programs by Borysow et al.
C
C created P. Irwin 1/96. AOPP, University of Oxford, England.
C updated for Radtrans2.0 by Pat Irwin	2/3/12
C
C ================ Modification History ==========================
C
C modified to include N2-H2, N2-N2, CH4-CH4, CH4-H2 and N2-CH4
C pair opacities by  C.Nixon, 1/97. AOPP, Oxford.
C
C modified by P.Irwin to concentrate on long wavelength range for ISO
C
C (note: UNIX you must compile all the .f files together into one
C executable. Subprograms:
C
C h2h2_v1s.f  h2he_v0s.f h2h2_v0s.f  h2h2_v2s.f  h2he_v1s.f
C n2n2_s.f n2h2_sub.f n2ch4_s.f ch4ch4_s.f h2ch4_s.f
C
c NT	18/6/04	swapped n2h2_s.f for a new program n2h2_sub.f
c			(modified from Borysows original, OK for slit>=4.3 only)
c
c NT	23/6/04	swapped h2ch4_s.f for a new program h2ch4_sub.f
c			(modified from Borysows original, OK for slit>=4.3 only)
c
C ================================================================

C variable declarations
      implicit double precision (a-h,o-z)

C k is the master-table of absorption co-efficients
      real k(9,25,1501)

C f is the frequency array, alf is the absorption co-efficient array
C and temps is the temperature array
      dimension f(601),alf(601), temps(25)
      character*100 opfile

C nine gas pairs at present:
C
C 1............H2-H2 (ortho:para = 1:1 `equilibrium')
C 2............H2-He                        "
C 3............H2-H2 (ortho:para = 3:1 `normal')
C 4............H2-He                        "
C 5............H2-N2
C 6............N2-CH4
C 7............N2-N2
C 8............CH4-CH4
C 9............H2-CH4
      parameter NUMPAIRS=9

C set limits of calculation grid and step size
      parameter TMIN=40.0          ! you can change this
      parameter TSTEP=15.0         ! and this, but not
      parameter NUMTEMPS=25        ! this.

      parameter NUMWN=1501         ! don't change this
      parameter DNU=1.0            ! or this, because then other programs
C                                    which read the table will get confused
      ddnu = DNU
C can't pass a parameter to a subroutine!


      print*,'Program ISOTABLE - calculates pressure-induced'
      print*,'                   absorption co-efficients.'
      print*,' '
      print*,'Enter name of output file : '
      read(5,1)opfile
1     format(a)

      print*, 'Temperature range is: ', TMIN, ' to ',
     &         TMIN+(TSTEP*NUMTEMPS)

      print*, 'Enter width of slit for N2-H2, N2-N2 and H2-CH4: '
      read (5,*) slit

C initialise the table of absorption-co-efficients by setting
C all entries = 0
       do 6 i1=1,NUMPAIRS
        do 7 i2=1,NUMTEMPS
         do 8 i3=1,NUMWN
          k(i1,i2,i3)= 0.0
8        continue
7       continue
6      continue

       do 200 itemp = 1,NUMTEMPS
	  temps(itemp) = TMIN + (itemp - 1)*TSTEP
          print*,'temp = ',temps(itemp)

C this loop for equilibrium and normal ortho:para H2
          do 250, normal=0,1

             if (normal .eq. 0) then
                igas = 1
             else
                igas = 3
             endif
             print*, 'normal =', normal

             temp=temps(itemp)

             do istep = 1,3
              fnumin=0. + (istep - 1)*500.0
              fnumax=fnumin + 499.0
              nf = 0
              call h2h2_v0s(normal,temp,fnumin,fnumax,ddnu,nf,f,alf)
              do i=1,nf
                 j=1 + int(f(i)/DNU)
                 k(igas,itemp,j)=k(igas,itemp,j)+sngl(alf(i))
              end do
             enddo
             print*,'h2h2_v0 OK'

             if (normal .eq. 0) then
                igas = 2
             else
                igas = 4
             endif

             temp=temps(itemp)
             do istep = 1,3
              fnumin=0. + (istep-1)*500.0
              fnumax=fnumin + 499.0
              call h2he_v0s(normal,temp,fnumin,fnumax,ddnu,nf,f,alf)
              do i=1,nf
                 j=1 + int(f(i)/ddnu)
                 k(igas,itemp,j)=k(igas,itemp,j)+sngl(alf(i))
              end do
             enddo
             print*,'h2he_v0 OK'

 250      continue

C =========================== N2 - H2 ===========================
 255      igas = 5
          temp=temps(itemp)
          do istep = 1,3
           fnumin=0.0 + (istep-1)*500.0
           fnumax = fnumin + 499.0
           nf = 0
           call n2h2_sub(temp,fnumin,fnumax,ddnu,nf,f,alf,slit)
           do i=1,nf
              j=1 + int(f(i)/ddnu)
              k(igas,itemp,j)=k(igas,itemp,j)+sngl(alf(i))
           end do
          enddo
          print*,'n2h2 OK'

C =========================== N2 - CH4 ===========================
 256      igas = 6
          temp=temps(itemp)
          do istep = 1,2
           fnumin=0.0 + (istep-1)*500.0
           fnumax = fnumin+499.0
           nf = 0
           call n2ch4_s(temp,fnumin,fnumax,ddnu,nf,f,alf)
           do i=1,nf
              j=1 + int(f(i)/ddnu)
              k(igas,itemp,j)=k(igas,itemp,j)+sngl(alf(i))
           end do
          enddo
          print*,'n2ch4 OK'

C =========================== N2 - N2 ===========================
 257      igas = 7
          temp=temps(itemp)
          do istep = 1,2
           fnumin=0 + (istep-1)*500.0
           fnumax = fnumin + 499.0
           nf = 0
           call n2n2_s(temp,fnumin,fnumax,ddnu,nf,f,alf,slit)
           do i=1,nf
              j=1 + int(f(i)/ddnu)
              k(igas,itemp,j)=k(igas,itemp,j)+sngl(alf(i))
           end do
          enddo
          print*,'n2n2 OK'

C =========================== CH4 - CH4 ===========================
 258      igas = 8
          temp=temps(itemp)
          do istep = 1,3
           fnumin=0 + (istep-1)*500.0
           fnumax = fnumin + 499.0
           nf = 0
           call ch4ch4_s(temp,fnumin,fnumax,ddnu,nf,f,alf)
           do i=1,nf
              j=1 + int(f(i)/ddnu)
              k(igas,itemp,j)=k(igas,itemp,j)+sngl(alf(i))
           end do
          enddo
          print*,'ch4ch4 OK'

C =========================== CH4 - H2 ===========================
 259      igas = 9

C NB ********* there is a problem with this code:
C the CH4 octopole spectrum is going wrong at T > 150 K (approx)
C The effect gets worse with temp (try plotting it - strange spikes
C are appearing). Anyway, leaving this code in for the time being
C because the error is seemingly small.

C Actually its quite pathological at times! PGJI 3/6/98

C Problematic program replaced with h2ch4_sub. Output no agrees
c with Borysows original and ouput doesn't contain spikes. NT 23/6/04

          temp=temps(itemp)
          do istep = 1,3
           fnumin=0 + (istep-1)*500.0
           fnumax = fnumin + 499.0
           nf = 0
           call h2ch4_sub(temp,fnumin,fnumax,ddnu,nf,f,alf,slit)
           do i=1,nf
              j=1 + int(f(i)/ddnu)
              
              k(igas,itemp,j)=k(igas,itemp,j)+sngl(alf(i))
           end do
          enddo
          print*,'h2ch4 OK'

 200    continue

 201    print*,'Calculation complete'

      open(12,file=opfile,form='unformatted',status='unknown')

      write(12) temps
      write(12) k
      close(12)

      end


