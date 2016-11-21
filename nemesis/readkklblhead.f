      subroutine readkklblhead(runname,vkstart,vkend,vkstep)
C     ****************************************************************
C     Subroutine to read in the header of the first .kta file to determine
C     the range and step of the k-tables.
C
C     Pat Irwin		10/2/04
C  
C     ****************************************************************
      implicit none
      include '../radtran/includes/arrdef.f'
      character*100 kname,runname
      integer lun0,npoint,idgas,isogas,np,nt,irec0
      real vcen(MAXBIN)
      real vmin,delv,fwhm,press(MAXK),temp(MAXK)
      real vkstart,vkend,vkstep,temp2(MAXK,MAXK)

      call file(runname,runname,'kls')
1     format(a100)


      open(12,file=runname,status='old')
        read(12,1)kname
      close(12)


C      print*,'Reading header information from : '
C      write(6,1)kname

      lun0 = 100

      call read_klblhead(kname,lun0,npoint,vmin,delv,fwhm,vcen,
     1  idgas,isogas,press,temp,temp2,np,nt,irec0)
      close(100)


      vkstep = delv
      vkstart = vmin
      vkend = vkstart + delv*(npoint-1)

      return
 
      end
