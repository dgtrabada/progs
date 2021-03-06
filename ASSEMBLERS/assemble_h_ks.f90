! copyright info:
!
!                             @Copyright 2005
!                     Fireball Enterprise Center, BYU
! Brigham Young University - James P. Lewis, Chair
! Arizona State University - Otto F. Sankey
! Universidad de Madrid - Jose Ortega
! Institute of Physics, Czech Republic - Pavel Jelinek

! Other contributors, past and present:
! Auburn University - Jian Jun Dong
! Arizona State University - Gary B. Adams
! Arizona State University - Kevin Schmidt
! Arizona State University - John Tomfohr
! Lawrence Livermore National Laboratory - Kurt Glaesemann
! Motorola, Physical Sciences Research Labs - Alex Demkov
! Motorola, Physical Sciences Research Labs - Jun Wang
! Ohio University - Dave Drabold
! University of Regensburg - Juergen Fritsch

!
! fireball-qmd is a free (GPLv3) open project.

! This program is free software: you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation, either version 3 of the License, or
! (at your option) any later version.
!
! This program is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! GNU General Public License for more details.
!
! You should have received a copy of the GNU General Public License
! along with this program.  If not, see <http://www.gnu.org/licenses/>.


! readdata.f90
! Program Description
! ===========================================================================
!       This routine reads the different data file.
!
! ===========================================================================

! ===========================================================================
!
! Program Declaration
! ===========================================================================
        subroutine assemble_h_ks ()

        use options
        use outputs
        use mpi_main
        use scf
        use neighbor_map
        use configuration
        use interactions
        use energy
        use md

        implicit none

! Argument Declaration and Description
! ===========================================================================
! Output

! Local Parameters and Data Declaration
! ===========================================================================

! Local Variable Declaration and Description
! ===========================================================================
        integer iatom
        integer jatom
        integer ineigh
        integer mbeta
        integer kforce

! Procedure
! ===========================================================================

        write (*,*) '  '
        write (*,100)
        write (*,*) ' Now we are assembling KS Hamiltonian. '
        write (*,*) '  '

! ===========================================================================
!                             neighbors mapping
! ===========================================================================
! Only do these neighbor calculations if we are on the first step of the
! self-consistent cycle.

! Find all neighbors to atoms in the central cell. An atom is at lattice
! vector l(beta), and basis b(j). We refer to this as (beta,j). An atom in
! the central cell is at (0,j). Find all neighbors to atom (0,i)

! neighn(iatom) = # of neighbors of iatom
! neighj(iatom,ineigh) = j-sub-m, the jatom value of the ineigh'th neighbor.
! neighb(iatom,ineigh) = beta-sub-m, the beta value for the ineigh'th neighbor.
          if (Kscf .eq. 1) then
           if (ifixneigh .eq. 0) then
            call reallocate_neigh (nprocs, my_proc, iordern,         &
     &                             itheory, itheory_xc, igauss, icluster,    &
     &                             ivdw, iwrthampiece,       &
     &                             iwrtatom, igrid)
            call neighbors (nprocs, my_proc, iordern, icluster,      &
     &                      iwrtneigh, ivdw)
            call neighborsPP (nprocs, my_proc, iordern, icluster,    &
     &                        iwrtneigh)
            call num_neigh_tot (numorb_max)
! bias voltage option
             if (ibias .eq. 1) then
              call reallocate_bias (natoms)
             endif

           else

            write (*,*) ' Using neighbor map from NEIGHBORS file. '
            call initneighbors (natoms, ivdw, nstepi)
            call num_neigh_tot (numorb_max)

           end if

           call backnay ()
             !SFIRE
            call neighbors_pairs(icluster)
            !SFIRE
           call common_neighbors (nprocs, my_proc, iordern, iwrtneigh_com)
           call common_neighborsPP (nprocs, my_proc, iordern,        &
     &                              iwrtneigh_com, icluster)
          end if ! end if (Kscf .eq. 1)



! ===========================================================================
! ---------------------------------------------------------------------------
!                   A S S E M B L E    H A M I L T O N I A N
!              A N D   O B T A I N   B A N D - S T R U C T U R E
! ---------------------------------------------------------------------------
! ===========================================================================
! Assemble the matrix elements of the Hamiltonian - all in real space.

! Set up neigh_self.  The variable neigh_self(natoms) is the ineigh value
! for the "self interaction".  Find the neighbor-number of iatom with itself
! (neigh_self) in order to put the result of VNA_atom (doscentros) into
! VNA(mu,nu,iatom,neigh_self).
! Initialize to something ridiculous.
          neigh_self = -999
          do iatom = 1, natoms
           do ineigh = 1, neighn(iatom)
            mbeta = neigh_b(ineigh,iatom)
            jatom = neigh_j(ineigh,iatom)
            if (iatom .eq. jatom .and. mbeta .eq. 0) neigh_self(iatom) = ineigh
           end do
          end do
          neighPP_self = -999
          do iatom = 1, natoms
           do ineigh = 1, neighPPn(iatom)
            mbeta = neighPP_b(ineigh,iatom)
            jatom = neighPP_j(ineigh,iatom)
            if (iatom .eq. jatom .and. mbeta .eq. 0)                         &
     &       neighPP_self(iatom) = ineigh
           end do
          end do

          if (ivdw .eq. 1) then
           neigh_vdw_self = -999
           do iatom = 1, natoms
            do ineigh = 1, neighn_vdw(iatom)
             mbeta = neigh_b_vdw(ineigh,iatom)
             jatom = neigh_j_vdw(ineigh,iatom)
             if (iatom .eq. jatom .and. mbeta .eq. 0)                        &
     &        neigh_vdw_self(iatom) = ineigh
            end do
           end do
          end if

          write(*,*) '  '
          if (Kscf .eq. 1) then
! ===========================================================================
!                               assemble_2c
! ===========================================================================
! We now do the 2center contributions - assemble_2c does the assembly and
! doscentros does the interpolating and "fundamental" calculations.
! assemble_2c ONLY does 2c terms. No 3c terms allowed. See assemble_3c
! and trescentros for 3c terms.
           write (*,*) ' Assemble two-center interactions. '
           call assemble_sVNL (iforce)
           call assemble_2c (nprocs, iforce, iordern, ioff2c)
           call assemble_2c_PP (nprocs, iforce, iordern)
! assemble bias matrix
!            if (ibias .eq. 1) call assemble_Vbias (nprocs, iforce, iordern, &
!     &                        ioff2c)

! ===========================================================================
!                               assemble_3c
! ===========================================================================
! We now do the 3center contributions - assemble_3c does the assembly and
! trecentros does the interpolating and "fundamental" calculations.
! assemble_3c ONLY does 3c terms. No 2c terms allowed. See assemble_2c
! and doscentros for 2c terms.
           write(*,*) '  '
           write (*,*) ' Assemble three-center interactions. '
           call assemble_3c (nprocs, iordern, igauss, itheory_xc)
           write (*,*) ' Assemble three-center PP interactions. '
           call assemble_3c_PP (nprocs, iordern)
! ===========================================================================
!                               assemble_GRID
! ===========================================================================
!           write (*,*) ' Map psi onto the mesh'
!           call psi2mesh ()
!           write (*,*) ' Map psi*psi onto the mesh'
!           call psi22mesh ()
           write (*,*) ' Assemble atomic density '
           call assemble_KS_den0 ()
           write (*,*) ' Assemble neutral atomic potential '
           call assemble_KS_vna ()

          end if ! end if of Kscf = 1

! solve Poisson equation to get the variation Hartree potential
          write (*,*) ' Solve Poisson equation'
!           call laplace_fdm (natoms, icluster, a1vec, a2vec, a3vec)
          call laplace_fft (icluster, ibias)

          write (*,*) ' Assemble matrices'
          call assemble_KS_mat (natoms, nspecies, icluster, rcutoff)

! ===========================================================================
!                                 Build H
! ===========================================================================
! Set up the full Hamiltonian and writeout HS.dat.
          call buildh (nprocs, itheory, iordern, itestrange,    &
     &                 testrange, ibias, iwrtHS)
! ===========================================================================
! For iwrthampiece .eq. 1 (file - output.input), write out Hamiltonian pieces
          if (iwrthampiece .eq. 1) then
           call hampiece (itheory)
          end if


! Deallocate Arrays
! ===========================================================================


! Format Statements
! ===========================================================================
100     format (2x, 70('='))


        return
        end subroutine assemble_h_ks

