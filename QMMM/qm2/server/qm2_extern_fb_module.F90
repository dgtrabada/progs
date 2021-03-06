#include "../include/dprec.fh"
module qm2_extern_fb_module
! ----------------------------------------------------------------
! Interface for Fireball based QM and QM/MM MD 
!
! Currently supports:
! pure QM
! QM/MM with cutoff for QM-MM electrostatics under periodic
! boundary conditions
!
! Author: Jesus I. Mendieta-Moreno (jesus.mendieta@uam.es)
!
! Date: November 2010
!
! ----------------------------------------------------------------

  use qm2_extern_util_module, only: debug_enter_function, debug_exit_function

  implicit none

  private
  public :: get_fb_forces, fb_finalize
  logical, save :: do_mpi = .false.  ! Used in finalize subroutine

  character(len=*), parameter :: module_name = "qm2_extern_fb_module"

  type fb_nml_type
        ! Poner los input de fireball
     character(len=20) :: executable
     integer :: max_scf_iterations
     integer :: qmmm_int
     integer :: idftd3
     integer :: idipole
     integer :: debug
     integer :: mpi
     integer :: iqout
     integer :: imcweda
     integer :: ihorsfield
     integer :: iensemble
     integer :: imdet
     integer :: nddt
     integer :: icluster
     integer :: iwrtpop
     integer :: iwrtvel
     integer :: iwrteigen
     integer :: iwrtefermi
     integer :: iwrtdos
     integer :: ifixcharge
     integer :: iwrtewf
     integer :: iwrtatom
     integer :: iewform
     integer :: npbands
     integer :: mix_embedding
     integer :: iwrtcharges
     real :: cut_embedding
     real :: tempfe
     real :: sigmatol
     character(len=100) :: basis
     integer, dimension(200) :: pbands     
  end type fb_nml_type

  integer, save         :: newcomm ! Initialized in mpi_init subroutine

contains

  ! --------------------------------------
  ! Get QM energy and forces from TeraChem
  ! --------------------------------------
  subroutine get_fb_forces( do_grad, nstep, ntpr_default, id, nqmatoms, qmcoords,&
       qmtypes, nclatoms, clcoords, escf, dxyzqm, dxyzcl, charge, spinmult)

    use qm2_extern_util_module, only: print_results, check_installation, write_dipole, write_charges
    use constants, only: CODATA08_AU_TO_KCAL, CODATA08_A_TO_BOHRS, ZERO

    logical, intent(in) :: do_grad              ! Return gradient/not
    integer, intent(in) :: nstep                ! MD step number
    integer, intent(in) :: ntpr_default         ! frequency of printing
    character(len=3), intent(in) :: id          ! ID number for PIMD or REMD
    integer, intent(in) :: nqmatoms             ! Number of QM atoms
    _REAL_,  intent(in) :: qmcoords(3,nqmatoms) ! QM coordinates
    integer, intent(in) :: qmtypes(nqmatoms)    ! QM atom types (nuclear charge in au)
    integer, intent(in) :: nclatoms             ! Number of MM atoms
    _REAL_,  intent(in) :: clcoords(4,nclatoms) ! MM coordinates and charges in au
    _REAL_, intent(out) :: escf                 ! SCF energy
    _REAL_, intent(out) :: dxyzqm(3,nqmatoms)   ! SCF QM force
    _REAL_, intent(out) :: dxyzcl(3,nclatoms)   ! SCF MM force
    integer, intent(in) :: charge, spinmult     ! Charge and spin multiplicity

    _REAL_              :: dipmom(4,3)          ! Dipole moment {x, y, z, |D|}, {QM, MM, TOT}

    type(fb_nml_type), save :: fb_nml
    logical, save :: first_call = .true.
    integer :: i
    integer :: printed =-1 ! Used to tell if we have printed this step yet 
                           ! since the same step may be called multiple times
    character(len=150) :: call_buffer

    ! assemble input - / output data filenames

    
    ! Setup on first program call
    if ( first_call ) then
      first_call = .false.
      write (6,*) '>>> Running QM calculation with Fireball  <<<'
      call get_namelist( fb_nml )
      call check_installation( trim(fb_nml%executable), id, .true., fb_nml%debug )
    end if

#ifdef MPI
# ifndef MPI_1
    if (fb_nml%mpi==1 ) then ! Do mpi (forced to 0 ifndef MPI)
      call mpi_hook( nqmatoms, qmcoords, qmtypes, nclatoms, clcoords,&
        fb_nml, escf, dxyzqm, dxyzcl, dipmom, do_grad, id, charge, spinmult )
    else
# else
    ! If we are using MPI 1.x the code will not compile since
    ! MPI_LOOKUP_NAME is part of the MPI 2 standard, so  just quit
    if (fb_nml%mpi==1 ) then 
    call sander_bomb('(qm2_extern_fb_module)', &
      '&unsupported MPI version', &
      'Will quit now.')
    else
# endif
#endif
      


#ifdef MPI
    end if
#endif

    if ( do_grad ) then
       ! Convert Hartree/Bohr -> kcal/(mol*A)
       dxyzqm(:,:) = dxyzqm(:,:) !* 14.39975d0 * 23.061d0
       if ( nclatoms > 0 ) then
          dxyzcl(:,:) = dxyzcl(:,:)
       end if
    else
       dxyzqm = ZERO
       if ( nclatoms > 0 ) dxyzcl = ZERO
    end if

    !escf = escf * CODATA08_AU_TO_KCAL



  end subroutine get_fb_forces


  subroutine get_namelist(fb_nml)

    use UtilitiesModule, only: Upcase
    implicit none
    character(len=20) :: executable
    !integer, intent(in) :: ntpr_default
    type(fb_nml_type), intent(out) :: fb_nml
    integer :: mpi, max_scf_iterations, qmmm_int, idftd3, debug, iqout, iensemble,        &
               imcweda, ihorsfield, imdet, nddt, icluster, iwrtpop, iwrtvel, iwrteigen,   &
               iwrtefermi, iwrtdos, ifixcharge, iwrtewf, iwrtatom, iewform, idipole,      &
               npbands, mix_embedding, iwrtcharges
    real :: cut_embedding, tempfe, sigmatol
    character (len = 100) :: basis
    integer, dimension(200) :: pbands
    namelist /fb/ mpi, executable, max_scf_iterations, qmmm_int, idftd3, debug, iqout,   &
               imcweda, ihorsfield, iensemble, imdet, nddt, icluster, iwrtpop, iwrtvel,  &
               iwrteigen, iwrtefermi, iwrtdos, ifixcharge, iwrtewf, iwrtatom,            &
               iewform, npbands, idipole, pbands, mix_embedding, cut_embedding,          &
               iwrtcharges, tempfe, sigmatol, basis
    integer :: i, ierr
     executable      = "fireball_server"
   
    mpi          = 1 ! Default to using MPI if available


    ! Default values
    executable = "fireball_server"
    max_scf_iterations = 70
    qmmm_int = 1
    idftd3 = 0
    idipole = 1
    debug = 0
    mpi = 1
    iqout = 1
    imcweda = 1
    ihorsfield = 0
    iensemble = 0
    imdet = 0
    nddt = 1000
    icluster = 1
    iwrtpop = 0
    iwrtvel = 0
    iwrteigen = 0
    iwrtefermi = 0 
    iwrtdos = 0
    ifixcharge = 0
    iwrtewf = 0
    iwrtatom = 0
    iewform = 0
    npbands = 0
    pbands = 0
    mix_embedding = 0
    cut_embedding = 99.0d0
    iwrtcharges = 0
    tempfe = 100.0d0
    sigmatol = 1.0E-8
    basis = 'Fdata'

    ! Read namelist, 
    rewind 5
    read(5,nml=fb,iostat=ierr)

#ifndef MPI
        if ( fb_nml%mpi == 1 ) then
          write(6,'(a)') '| Warning: mpi=1 selected but sander was not compiled with MPI support.'
          write(6,'(a)') '| Continuing with mpi=0'
        end if
        fb_nml%mpi         = 0 ! Can't pick MPI if not available 
#else
        fb_nml%mpi         = mpi
#endif

    ! Assign namelist values to fb_nml data type
    fb_nml%executable           = executable
    fb_nml%max_scf_iterations   = max_scf_iterations
    fb_nml%qmmm_int             = qmmm_int
    fb_nml%idftd3               = idftd3
    fb_nml%idipole              = idipole
    fb_nml%debug                = debug
    fb_nml%iqout                = iqout
    fb_nml%imcweda              = imcweda
    fb_nml%ihorsfield           = ihorsfield
    fb_nml%iensemble            = iensemble
    fb_nml%imdet                = imdet
    fb_nml%nddt                 = nddt
    fb_nml%icluster             = icluster  
    fb_nml%iwrtpop              = iwrtpop
    fb_nml%iwrtvel              = iwrtvel
    fb_nml%iwrteigen            = iwrteigen
    fb_nml%iwrtefermi           = iwrtefermi  
    fb_nml%iwrtdos              = iwrtdos
    fb_nml%ifixcharge           = ifixcharge
    fb_nml%iwrtewf              = iwrtewf
    fb_nml%iwrtatom             = iwrtatom
    fb_nml%iewform              = iewform
    fb_nml%npbands              = npbands
    fb_nml%pbands               = pbands
    fb_nml%mix_embedding        = mix_embedding
    fb_nml%cut_embedding        = cut_embedding
    fb_nml%iwrtcharges          = iwrtcharges
    fb_nml%tempfe               = tempfe
    fb_nml%sigmatol             = sigmatol
    fb_nml%basis                = basis

    ! Need this variable so we don't call MPI_Send in the finalize subroutine
    if (mpi==1 ) then
      do_mpi=.true.
    end if

  end subroutine get_namelist

  ! --------------------------------
  ! Print Fireball namelist settings
  ! --------------------------------
  subroutine write_inpfile( fb_nml, qmcoords, nqmatoms, charge)

    use qmmm_module, only : qmmm_struct

    implicit none
    type(fb_nml_type), intent(in) :: fb_nml
    _REAL_           , intent(in) :: qmcoords(:,:)
    integer          , intent(in) :: charge
    integer          , intent(in) :: nqmatoms
    integer :: k

    open (unit = 226, file = 'fireball.in', status = 'unknown')

    write (226,600) "&option"
    
    if (fb_nml%ihorsfield .eq. 1) then
    write (226,600) "imcweda = 0"
    write (226,600) "ihorsfield = 1"
    end if
    write (226,601) "qstate = ", -1*charge
    write (226,602) "iqout = ", fb_nml%iqout
    write (226,602) "icluster = ", fb_nml%icluster
    write (226,603) "max_scf_iterations = ", fb_nml%max_scf_iterations
    write (226,602) "iensemble = ", fb_nml%iensemble
    write (226,602) "imdet = ", fb_nml%imdet
    write (226,605) "nddt = ", fb_nml%nddt
    write (226,602) "iqmmm = ", fb_nml%qmmm_int
    write (226,602) "ifixcharge =", fb_nml%ifixcharge
    write (226,600) "iquench = 0"
    write (226,602) "idftd3 = ",fb_nml%idftd3
    write (226,606) "tempfe =", fb_nml%tempfe
    write (226,607) "sigmatol =", fb_nml%sigmatol
    write (226,609) "fdataLocation = '", fb_nml%basis,"'"
    write (226,602) "idipole = ",fb_nml%idipole
    write (226,602) "mix_embedding = ", fb_nml%mix_embedding
    write (226,606) "cut_embedding = ", fb_nml%cut_embedding
    write (226,600) "&end"
    write (226,600) "&output"
    write (226,602) "iwrtcharges = ",fb_nml%iwrtcharges 
    write (226,602) "iwrtpop = ", fb_nml%iwrtpop
    write (226,602) "iwrtvel = ", fb_nml%iwrtvel
    write (226,602) "iwrteigen = ", fb_nml%iwrteigen
    write (226,602) "iwrtefermi = ", fb_nml%iwrtefermi
    write (226,602) "iwrtdos = ", fb_nml%iwrtdos
    write (226,602) "iwrtewf = ",fb_nml%iwrtewf
    write (226,602) "iwrtatom = ",fb_nml%iwrtatom
    write (226,600) "&end"
    if (fb_nml%iwrtewf .eq. 1) then
    write (226,600) "&mesh"
    write (226,603) "iewform = ", fb_nml%iewform
    write (226,603) "npbands = ", fb_nml%npbands
    write (226,608) "pbands = ", fb_nml%pbands
    write (226,600) "&end"
    end if

    open (unit = 227, file = 'input.bas', status = 'unknown')

    write (227,*) nqmatoms
    do k = 1, nqmatoms
      write (227,700) qmmm_struct%iqm_atomic_numbers(k), qmcoords(:,k)
    end do



! Format Statements
! ===========================================================================
600     format (a)!(a,f8.5)
601     format (a,i2)
602     format (a,i1)
603     format (a,i3)
604     format (a,i1)
605     format (a,i4)
606     format (a,f8.3)
607     format (a,e13.6)
608     format (a,199(i4,','),i3)
609     format (a,a,a)
700     format (i2, 3(2x,f8.4))

  end subroutine write_inpfile



#if defined(MPI) && !defined(MPI_1)
  ! Perform MPI communications with terachem. Requires MPI 2.0 or above to use
  subroutine mpi_hook( nqmatoms, qmcoords, qmtypes, nclatoms, clcoords,&
       fb_nml, escf, dxyzqm, dxyzcl, dipmom, do_grad, id, charge, spinmult )
    
    use ElementOrbitalIndex, only : elementSymbol
    use qm2_extern_util_module, only: check_installation    
    
    implicit none
    include 'mpif.h'

    integer, intent(in) :: nqmatoms
    _REAL_,  intent(in) :: qmcoords(3,nqmatoms) 
    integer, intent(in) :: qmtypes(nqmatoms)
    integer, intent(in) :: nclatoms
    _REAL_,  intent(in) :: clcoords(4,nclatoms)
    type(fb_nml_type), intent(in) :: fb_nml
    _REAL_, intent(out) :: escf
    _REAL_, intent(out) :: dxyzqm(3,nqmatoms)
    _REAL_, intent(out) :: dxyzcl(3,nclatoms)
    _REAL_, intent(out) :: dipmom(4,3)
    logical, intent(in) :: do_grad
    character(len=3), intent(in) :: id
    integer         , intent(in) :: charge, spinmult

    character(len=2)    :: atom_types(nqmatoms)
    _REAL_              :: qmcharges(nqmatoms)
    _REAL_              :: coords(3,nqmatoms+nclatoms)
    _REAL_              :: charges(nclatoms)
    _REAL_              :: dxyz_all(3,nclatoms+nqmatoms)

    logical,save        :: first_call=.true.
    integer             :: i, status(MPI_STATUS_SIZE)
    integer             :: ierr

    integer :: system
    integer :: stat

    call debug_enter_function( 'mpi_hook', module_name, fb_nml%debug )


    ! ---------------------------------------------------
    ! Initialization: Connect to "terachem_port", set    
    ! newcomm (global), send relevant namelist variables.
    ! ---------------------------------------------------

    if (first_call) then 
      first_call=.false.
      call write_inpfile( fb_nml, qmcoords, nqmatoms, charge)
      call connect_to_fireball( fb_nml, nqmatoms, atom_types, do_grad, id, charge, spinmult )
    end if

       call MPI_SEND(qmcoords,3*nqmatoms, MPI_DOUBLE_PRECISION, 0, 0, newcomm, ierr) 
       call MPI_SEND(nclatoms, 1, MPI_INTEGER, 0, 0, newcomm, ierr )
       call MPI_SEND(clcoords,4*nclatoms, MPI_DOUBLE_PRECISION, 0, 0, newcomm,ierr)

       call MPI_Recv(escf, 1, MPI_DOUBLE_PRECISION, 0, 0, newcomm, status, ierr )
       call MPI_RECV(dxyzqm,3*nqmatoms, MPI_DOUBLE_PRECISION, 0, 0, newcomm,status,ierr)
       call MPI_RECV(dxyzcl,3*nclatoms, MPI_DOUBLE_PRECISION, 0, 0, newcomm,status,ierr)
       call MPI_Recv(qmcharges, nqmatoms, MPI_DOUBLE_PRECISION, 0, 0, newcomm,status,ierr)

!       write(*,*) 'Received the following charges from server:'
!       do i=1, nqmatoms
!          write(*,*) 'Atom ',i, ': ', qmcharges(i)
!       end do


  end subroutine mpi_hook

  ! -------------------------------------------------
  ! Search for name published by TeraChem and connect
  ! (this step initializes newcomm)
  ! Send relevant namelist variables to terachem
  ! -------------------------------------------------
  subroutine connect_to_fireball( fb_nml, nqmatoms, atom_types, do_grad, id, charge, spinmult )

    implicit none
    include 'mpif.h'
    
    type(fb_nml_type), intent(in) :: fb_nml
    integer          , intent(in) :: nqmatoms
    character(len=2) , intent(in) :: atom_types(nqmatoms)
    logical          , intent(in) :: do_grad
    character(len=3) , intent(in) :: id
    integer          , intent(in) :: charge, spinmult

    character(len=15) :: server_name= "fireball_server"
    integer, parameter  :: clen=128 ! Length of character strings we are using
    character(len=255) :: port_name
    character(len=clen) :: dbuffer(2,32)
    _REAL_          :: timer
    integer         :: ierr, i, j, irow
    logical         :: done=.false.
 
    integer rank,  intercomm, status, size, mp

    print *, 'hola'

    !call debug_enter_function( 'connect_to_fireball', module_name, fb_nml%debug )

    ! -----------------------------------
    ! Look for server_name, get port name
    ! After 60 seconds, exit if not found
    ! -----------------------------------

    if ( trim(id) /= '' ) then
      server_name = trim(server_name)//'.'//trim(id)
    end if

    timer = MPI_WTIME(ierr)
    do while (done .eqv. .false.)

    call MPI_LOOKUP_NAME(trim(server_name), MPI_INFO_NULL, port_name, ierr)
      ierr=MPI_SUCCESS
      if (ierr == MPI_SUCCESS) then
        if ( fb_nml%debug > 1 ) then
          write(6,'(2a)') 'Found port: ', trim(port_name)
          call flush(6)
        end if
        done=.true.

      end if

      if ( (MPI_WTIME(ierr)-timer) > 60 ) then ! Time out after 60 seconds
        call sander_bomb('connect_to_fireball() ('//module_name//')', &
          '"'//trim(server_name)//'" not found. Timed out after 60 seconds.', &
          'Will quit now')
      end if
    end do

 ! ----------------------------------------
    ! Establish new communicator via port name
    ! ----------------------------------------


      ! call MPI_COMM_SIZE(MPI_COMM_WORLD, size, ierr)
      ! call MPI_COMM_RANK(MPI_COMM_WORLD, rank, ierr)



    call MPI_COMM_CONNECT(port_name, MPI_INFO_NULL, 0, MPI_COMM_SELF, newcomm, ierr)


    mp=0
    call MPI_SEND(mp,1, MPI_INTEGER, 0, 0, newcomm, ierr)



  end subroutine connect_to_fireball

#endif


  subroutine fb_finalize()

    implicit none
#ifdef MPI
    include 'mpif.h'

    integer :: ierr
    _REAL_  :: empty
    if (do_mpi) then
      call MPI_Send( empty, 1, MPI_DOUBLE_PRECISION, 0, 0, newcomm, ierr )
    end if
#endif

  end subroutine fb_finalize
      

end module qm2_extern_fb_module
