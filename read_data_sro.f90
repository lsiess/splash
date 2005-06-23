!-------------------------------------------------------------------------
! this subroutine reads from the data file(s)
! change this to change the format of data input
!
! THIS VERSION IS FOR READING UNFORMATTED OUTPUT FROM STEPHAN ROSSWOG'S CODE
! (ie. STRAIGHT FROM THE DATA DUMP)
!
! *** CONVERTS TO SINGLE PRECISION ***
!
! the data is stored in the global array dat
!
! >> this subroutine must return values for the following: <<
!
! ncolumns    : number of data columns
! ndim, ndimV : number of spatial, velocity dimensions
! nstepsread  : number of steps read from this file
!
! maxplot,maxpart,maxstep      : dimensions of main data array
! dat(maxplot,maxpart,maxstep) : main data array
!
! npartoftype(1:6,maxstep) : number of particles of each type in each timestep
!
! time(maxstep)       : time at each step
! gamma(maxstep)      : gamma at each step 
!
! most of these values are stored in global arrays 
! in the module 'particle_data'
!-------------------------------------------------------------------------

subroutine read_data(rootname,indexstart,nstepsread)
  use particle_data
  use params
  use settings_data, only:ndim,ndimV,ncolumns,ncalc
  use mem_allocation
  implicit none
  integer, intent(in) :: indexstart
  integer, intent(out) :: nstepsread
  character(len=*), intent(in) :: rootname
  integer, parameter :: maxptmass = 10
  integer :: i,j,ifile,ierr
  integer :: nprint,nptmass,npart_max,nstep_max
  integer :: n1,n2
  logical :: iexist,magfield,minidump,doubleprec
  character(len=len(rootname)) :: dumpfile
  real :: timei,tkin,tgrav,tterm,escap,rstar,mstar
  real(doub_prec) :: timedb,tkindb,tgravdb,ttermdb
  real(doub_prec) :: escapdb,rstardb,mstardb
  real(doub_prec), dimension(:,:), allocatable :: datdb

  nstepsread = 0
  nstep_max = 0
  npart_max = maxpart
  ifile = 1
  magfield = .true.

  dumpfile = trim(rootname)   
  !
  !--check if first data file exists
  !
  inquire(file=dumpfile,exist=iexist)
  if (.not.iexist) then
     print "(a)",' *** error: '//trim(dumpfile)//': file not found ***'    
     return
  endif
  !
  !--use minidump format if minidump
  !
  minidump = .false.
  if (dumpfile(1:8).eq.'minidump') minidump = .true.
  !
  !--fix number of spatial dimensions
  !
  ndim = 3
  ndimV = 3
  if (magfield) then
     if (minidump) then
        ncolumns = 11
     else
        ncolumns = 24
     endif
  else
     ncolumns = 7  ! number of columns in file  
  endif
  !
  !--allocate memory initially
  !
  nstep_max = max(nstep_max,indexstart,2)

  j = indexstart
  nstepsread = 0
  
  write(*,"(26('>'),1x,a,1x,26('<'))") trim(dumpfile)
  !
  !--open the (unformatted) binary file and read the number of particles
  !
     open(unit=15,iostat=ierr,file=dumpfile,status='old',form='unformatted')
     if (ierr /= 0) then
        print "(a)",'*** ERROR OPENING '//trim(dumpfile)//' ***'
     else
        !
        !--read the number of particles in the first step,
        !  allocate memory and rewind
        !
        doubleprec = .true.
        if (minidump) then
           !--try double precision first
           read(15,end=55,iostat=ierr) timedb,nprint,nptmass
           !--change to single precision if stupid answers
           if (nprint.le.0.or.nprint.gt.1e10 &
               .or.nptmass.lt.0.or.nptmass.gt.1e6) then
              doubleprec = .false.
              rewind(15)
              read(15,end=55,iostat=ierr) timei,nprint,nptmass
              print "(a)",' single precision dump'
           else
              print "(a)",' double precision dump'
              timei = real(timedb)
           endif
        else
           !--try double precision first
           read(15,end=55,iostat=ierr) nprint,rstardb,mstardb,n1,n2, &
                   nptmass,timedb
           !--change to single precision if stupid answers
           if (n1.lt.0.or.n1.gt.1e10.or.n2.lt.0.or.n2.gt.1e10 &
              .or.nptmass.lt.0.or.nptmass.gt.1.e6) then
              doubleprec = .false.
              rewind(15)
              read(15,end=55,iostat=ierr) nprint,rstar,mstar,n1,n2, &
                   nptmass,timei
              print "(a)",' single precision dump'
           else
              print "(a)",' double precision dump'
              timei = real(timedb)           
           endif
        endif
        print "(a,f10.2,a,i9,a,i6)",' time: ',timei,' npart: ',nprint,' nptmass: ',nptmass
 
       if (.not.allocated(dat) .or. (nprint+nptmass).gt.npart_max) then
           npart_max = max(npart_max,INT(1.1*(nprint+nptmass)))
           call alloc(npart_max,nstep_max,ncolumns)
        endif
        rewind(15)
     endif
     if (ierr /= 0) then
        print "(a)",'*** ERROR READING TIMESTEP HEADER ***'
     else
!
!--loop over the timesteps in this file
!     
        npart_max = max(npart_max,nprint)
!
!--allocate/reallocate memory if j > maxstep
!
        if (j.gt.maxstep) then
           call alloc(maxpart,j+1,maxcol)
        endif
!
!--now read the timestep data in the dumpfile
!
        if (magfield) then
           if (minidump) then
              dat(:,:,j) = 0.

              if (doubleprec) then
                 allocate(datdb(maxpart,11),stat=ierr)
                 if (ierr /= 0) then
                    print*,"(a)",'*** error allocating memory for double conversion ***'
                    return
                 else
                    datdb = 0.
                 endif
                 read(15,end=55,iostat=ierr) timedb,nprint,nptmass, &
                   (datdb(i,1),i=1,nprint),(datdb(i,2),i=1,nprint),  &
                   (datdb(i,3),i=1,nprint),(datdb(i,4),i=1,nprint),  &
                   (datdb(i,5),i=1,nprint),(datdb(i,6),i=1, nprint), &
                   (datdb(i,8),i=1,nprint),(datdb(i,9),i=1,nprint),  &
                   (datdb(i,10),i=1,nprint),(datdb(i,11),i=1,nprint),&
                   (datdb(i,7), i=nprint+1, nprint+nptmass), &
                   (datdb(i,1), i=nprint+1, nprint+nptmass), &
                   (datdb(i,2), i=nprint+1, nprint+nptmass), &
                   (datdb(i,3), i=nprint+1, nprint+nptmass)   
                if (ierr /= 0) then
                   print "(a)",'|*** ERROR READING (DOUBLE PRECISION) TIMESTEP ***'
                   if (allocated(datdb)) deallocate(datdb)
                   return
                else
                   dat(:,1:11,j) = real(datdb(:,1:11))
                   time(j) = real(timedb)
                endif
                            
              else
                 read(15,end=55,iostat=ierr) time(j),nprint,nptmass, &
                   (dat(i,1,j),i=1,nprint),(dat(i,2,j),i=1,nprint),  &
                   (dat(i,3,j),i=1,nprint),(dat(i,4,j),i=1,nprint),  &
                   (dat(i,5,j),i=1,nprint),(dat(i,6,j),i=1, nprint), &
                   (dat(i,8,j),i=1,nprint),(dat(i,9,j),i=1,nprint),  &
                   (dat(i,10,j),i=1,nprint),(dat(i,11,j),i=1,nprint),&
                   (dat(i,7,j), i=nprint+1, nprint+nptmass), &
                   (dat(i,1,j), i=nprint+1, nprint+nptmass), &
                   (dat(i,2,j), i=nprint+1, nprint+nptmass), &
                   (dat(i,3,j), i=nprint+1, nprint+nptmass)
              endif
              dat(1:nprint,7,j) = 1.4/real(nprint)
              print "(a,1pe10.4)", &
                   ' WARNING: hardwiring particle masses on minidump to ', &
                   1.4/real(nprint)
           else

              dat(:,:,j) = 0. ! because ptmasses don't have all quantities
           !
           !--read full dump
           !              
              if (doubleprec) then
                 allocate(datdb(maxpart,24),stat=ierr)
                 if (ierr /= 0) then
                    print*,"(a)",'*** error allocating memory for double conversion ***'
                    return
                 else
                    datdb = 0.
                 endif
                 read(15,end=55,iostat=ierr) nprint,rstardb,mstardb,n1,n2, &
                   nptmass,timedb,(datdb(i,7),i=1,nprint), &
                   escapdb,tkindb,tgravdb,ttermdb, &
                   (datdb(i,1),i=1,nprint),(datdb(i,2),i=1,nprint),  &
                   (datdb(i,3),i=1,nprint),(datdb(i,4),i=1,nprint),  &
                   (datdb(i,5),i=1,nprint),(datdb(i,6),i=1, nprint), &
                   (datdb(i,8),i=1,nprint),(datdb(i,9),i=1,nprint),  &
                   (datdb(i,10),i=1,nprint),(datdb(i,11),i=1,nprint),&
                   (datdb(i,12),i=1,nprint),(datdb(i,13),i=1,nprint),&
                   (datdb(i,14),i=1,nprint),(datdb(i,15),i=1,nprint),&
                   (datdb(i,16),i=1,nprint),(datdb(i,17),i=1,nprint),&
                   (datdb(i,18),i=1,nprint),(datdb(i,19),i=1,nprint),&
                   (datdb(i,20),i=1,nprint),(datdb(i,21),i=1,nprint),&
                   (datdb(i,22),i=1,nprint),(datdb(i,23),i=1,nprint),&
                   (datdb(i,24),i=1,nprint),&
                   (datdb(i,9), i=nprint+1, nprint+nptmass), &
                   (datdb(i,1), i=nprint+1, nprint+nptmass), &
                   (datdb(i,2), i=nprint+1, nprint+nptmass), &
                   (datdb(i,3), i=nprint+1, nprint+nptmass), &
                   (datdb(i,4), i=nprint+1, nprint+nptmass), &
                   (datdb(i,5), i=nprint+1, nprint+nptmass), &
                   (datdb(i,6), i=nprint+1, nprint+nptmass), &
                   (datdb(i,21), i=nprint+1, nprint+nptmass), &
                   (datdb(i,22), i=nprint+1, nprint+nptmass), &
                   (datdb(i,23), i=nprint+1, nprint+nptmass) 
                 if (ierr /= 0) then
                    print "(a)",'|*** ERROR READING (DOUBLE PRECISION) TIMESTEP ***'
                    if (allocated(datdb)) deallocate(datdb)
                    return
                 else
                    dat(:,1:24,j) = real(datdb(:,1:24))
                    time(j) = real(timedb)
                 endif                
              else
                 read(15,end=55,iostat=ierr) nprint,rstar,mstar,n1,n2, &
                   nptmass,time(j),(dat(i,7,j),i=1,nprint), &
                   escap,tkin,tgrav,tterm, &
                   (dat(i,1,j),i=1,nprint),(dat(i,2,j),i=1,nprint),  &
                   (dat(i,3,j),i=1,nprint),(dat(i,4,j),i=1,nprint),  &
                   (dat(i,5,j),i=1,nprint),(dat(i,6,j),i=1, nprint), &
                   (dat(i,8,j),i=1,nprint),(dat(i,9,j),i=1,nprint),  &
                   (dat(i,10,j),i=1,nprint),(dat(i,11,j),i=1,nprint),&
                   (dat(i,12,j),i=1,nprint),(dat(i,13,j),i=1,nprint),&
                   (dat(i,14,j),i=1,nprint),(dat(i,15,j),i=1,nprint),&
                   (dat(i,16,j),i=1,nprint),(dat(i,17,j),i=1,nprint),&
                   (dat(i,18,j),i=1,nprint),(dat(i,19,j),i=1,nprint),&
                   (dat(i,20,j),i=1,nprint),(dat(i,21,j),i=1,nprint),&
                   (dat(i,22,j),i=1,nprint),(dat(i,23,j),i=1,nprint),&
                   (dat(i,24,j),i=1,nprint),&
                   (dat(i,9,j), i=nprint+1, nprint+nptmass), &
                   (dat(i,1,j), i=nprint+1, nprint+nptmass), &
                   (dat(i,2,j), i=nprint+1, nprint+nptmass), &
                   (dat(i,3,j), i=nprint+1, nprint+nptmass), &
                   (dat(i,4,j), i=nprint+1, nprint+nptmass), &
                   (dat(i,5,j), i=nprint+1, nprint+nptmass), &
                   (dat(i,6,j), i=nprint+1, nprint+nptmass), &
                   (dat(i,21,j), i=nprint+1, nprint+nptmass), &
                   (dat(i,22,j), i=nprint+1, nprint+nptmass), &
                   (dat(i,23,j), i=nprint+1, nprint+nptmass) 
              endif  
           endif
        else
        !
        !--for hydro can only do minidumps at present
        !
           if (doubleprec) then
              allocate(datdb(maxpart,7),stat=ierr)
              if (ierr /= 0) then
                 print*,"(a)",'*** error allocating memory for double conversion ***'
                 return
              else
                 datdb = 0.
              endif
              read(15,end=55,iostat=ierr) timedb,nprint,nptmass, &
              (datdb(i,1), i=1, nprint), (datdb(i,2), i=1,nprint), &
              (datdb(i,3), i=1, nprint), (datdb(i,4), i=1,nprint), &
              (datdb(i,5), i=1, nprint), (datdb(i,6), i=1, nprint), &
              (datdb(i,7), i=nprint+1, nprint+nptmass), &
              (datdb(i,1), i=nprint+1, nprint+nptmass), &
              (datdb(i,2), i=nprint+1, nprint+nptmass), &
              (datdb(i,3), i=nprint+1, nprint+nptmass)
              if (ierr /= 0) then
                 print "(a)",'|*** ERROR READING (DOUBLE PRECISION) TIMESTEP ***'
                 if (allocated(datdb)) deallocate(datdb)
                 return
              else
                 dat(:,1:7,j) = real(datdb(:,1:7))
                 time(j) = real(timedb)
              endif
           else
              read(15,end=55,iostat=ierr) time(j),nprint,nptmass, &
              (dat(i,1,j), i=1, nprint), (dat(i,2,j), i=1,nprint), &
              (dat(i,3,j), i=1, nprint), (dat(i,4,j), i=1,nprint), &
              (dat(i,5,j), i=1, nprint), (dat(i,6,j), i=1, nprint), &
              (dat(i,7,j), i=nprint+1, nprint+nptmass), &
              (dat(i,1,j), i=nprint+1, nprint+nptmass), &
              (dat(i,2,j), i=nprint+1, nprint+nptmass), &
              (dat(i,3,j), i=nprint+1, nprint+nptmass)
           endif

           dat(1:nprint,7,j) = 1.4/real(nprint)
           print "(a,1pe10.4)", &
                ' WARNING: hardwiring particle masses on minidump to ', &
                1.4/real(nprint)
        endif
             
        if (allocated(datdb)) deallocate(datdb)
             
        if (ierr /= 0) then
           print "(a)",'|*** ERROR READING TIMESTEP ***'
           return
        else
           nstepsread = nstepsread + 1
        endif

        npartoftype(1,j) = nprint
        npartoftype(2,j) = nptmass

!!        print*,j,' time = ',time(j)
        gamma(j) = 1.666666666667
        j = j + 1
     
     endif

55 continue
  !
  !--reached end of file
  !
  close(15)

  print*,'>> end of dump file: nsteps =',j-1,'ntot = ', &
        sum(npartoftype(:,j-1)),'nptmass=',npartoftype(2,j-1)
   
return
                    
end subroutine read_data

!!------------------------------------------------------------
!! set labels for each column of data
!!------------------------------------------------------------

subroutine set_labels
  use filenames, only:rootname
  use labels
  use settings_data, only:ndim,ndimV,ncolumns,ntypes
  use geometry, only:labelcoord
  implicit none
  integer :: i
  logical :: minidump

  minidump = .false.
  if (rootname(1)(1:8).eq.'minidump') minidump = .true.
  
  if (ndim.le.0 .or. ndim.gt.3) then
     print*,'*** ERROR: ndim = ',ndim,' in set_labels ***'
     return
  endif
  if (ndimV.le.0 .or. ndimV.gt.3) then
     print*,'*** ERROR: ndimV = ',ndimV,' in set_labels ***'
     return
  endif
    
  do i=1,ndim
     ix(i) = i
  enddo
  if (minidump) then
     ivx = 0
     ih = 4        !  smoothing length
     irho = 5     ! location of rho in data array
     iutherm = 6  !  thermal energy
     ipmass = 7  !  particle mass
     if (ncolumns.gt.7) then
        iBfirst = 8
        idivB = 11 
     endif
  else !--full dump
     ivx = ndim+1
     ih = 7
     irho = 10
     iutherm = 8 
     ipmass = 9

     label(11) = 'temperature [ MeV ]'
     label(12) = 'electron fraction (y\de\u)'
     iBfirst = 13
     label(16) = 'psi'
     idivB = 17
     label(24) = 'dgrav'

     iamvec(18:20) = 18
     labelvec(18:20) = 'J'
     do i=1,ndimV
        label(18+i-1) = labelvec(18)//'\d'//labelcoord(i,1)
     enddo
     
     iamvec(21:23) = 21
     labelvec(21:23) = 'force'
     do i=1,ndimV
        label(21+i-1) = labelvec(21)//'\d'//labelcoord(i,1)
     enddo
  endif

  if (ivx.ne.0) then
     iamvec(ivx:ivx+ndimV-1) = ivx
     labelvec(ivx:ivx+ndimV-1) = 'v'
     do i=1,ndimV
        label(iBfirst+i-1) = labelvec(iBfirst)//'\d'//labelcoord(i,1)
     enddo
  endif

  if (iBfirst.ne.0) then
     iamvec(iBfirst:iBfirst+ndimV-1) = iBfirst
     labelvec(iBfirst:iBfirst+ndimV-1) = 'B'
     do i=1,ndimV
        label(iBfirst+i-1) = labelvec(iBfirst)//'\d'//labelcoord(i,1)
     enddo
     label(idivB) = 'div B'
  endif
  
  label(ix(1:ndim)) = labelcoord(1:ndim,1)
!  do i=1,ndimV
!     label(ivx+i-1) = 'v\d'//labelcoord(i,1)
!  enddo
  label(irho) = '\gr'      
  label(iutherm) = 'u'
  label(ih) = 'h       '
  label(ipmass) = 'particle mass'
  !
  !--set labels for each particle type
  !
  ntypes = 2 !!maxparttypes
  labeltype(1) = 'gas'
  labeltype(2) = 'point mass'
 
!-----------------------------------------------------------

  return 
end subroutine set_labels
