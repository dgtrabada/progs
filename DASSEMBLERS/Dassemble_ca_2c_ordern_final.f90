! copyright info:
!
!                             @Copyright 2002
!                            Fireball Committee
! Brigham Young University - James P. Lewis, Chair
! Arizona State University - Otto F. Sankey
! Universidad de Madrid - Jose Ortega

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

 
! Dassemble_ca_2c_ordern_final.f90
! Program Description
! ===========================================================================
!       Take contributions from each processor and perform an all_reduce 
! command to get all contributions combined to each processor.
!
! ===========================================================================
! Code written by:
! James P. Lewis
! Department of Physics and Astronomy
! Brigham Young University
! N233 ESC P.O. Box 24658
! Provo, UT 84602-4658
! FAX (801) 422-2265
! Office Telephone (801) 422-7444
! ===========================================================================
!
! Program Declaration
! ===========================================================================
        subroutine Dassemble_ca_2c_ordern_final (natoms)
        use forces
        use mpi_declarations
        use neighbor_map
        implicit none
 
        include 'mpif.h'

! Argument Declaration and Description
! ===========================================================================
! Input
        integer, intent (in) :: natoms
 
! Local Parameters and Data Declaration
! ===========================================================================
 
! Local Variable Declaration and Description
! ===========================================================================
        integer ierror

        real, dimension (:, :, :), allocatable :: r3_tmp

! BTN communication domain
        integer MPI_BTN_WORLD, MPI_OPT_WORLD, MPI_BTN_WORLD_SAVE
        common  /btnmpi/ MPI_BTN_WORLD, MPI_OPT_WORLD, MPI_BTN_WORLD_SAVE
 
! Allocate Arrays
! ===========================================================================
        allocate (r3_tmp (3, natoms, neigh_max))

! Procedure
! ===========================================================================
        call MPI_ALLREDUCE (faca, r3_tmp, 3*neigh_max*natoms,                &
     &                      mpi_whatever_real, MPI_SUM, MPI_BTN_WORLD, ierror)
        faca = r3_tmp
        call MPI_ALLREDUCE (faxc_ca, r3_tmp, 3*neigh_max*natoms,             &
     &                      mpi_whatever_real, MPI_SUM, MPI_BTN_WORLD, ierror)
        faxc_ca = r3_tmp
        call MPI_ALLREDUCE (fotca, r3_tmp, 3*neigh_max*natoms,               &
     &                      mpi_whatever_real, MPI_SUM, MPI_BTN_WORLD, ierror)
        fotca = r3_tmp
        call MPI_ALLREDUCE (fotxc_ca, r3_tmp, 3*neigh_max*natoms,            &
     &                      mpi_whatever_real, MPI_SUM, MPI_BTN_WORLD, ierror)
        fotxc_ca = r3_tmp

! Deallocate Arrays
! ===========================================================================
        deallocate (r3_tmp)
 
! Format Statements
! ===========================================================================
 
        return
        end
