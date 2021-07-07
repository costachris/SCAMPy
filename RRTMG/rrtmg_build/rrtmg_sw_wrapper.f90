module rrtmg_sw_wrapper

use iso_c_binding, only: c_double, c_int
use parrrsw, only : nbndsw, naerec, ngptsw
use rrtmg_sw_init, only: rrtmg_sw_ini
use mcica_subcol_gen_sw,  only: mcica_subcol_sw
use rrtmg_sw_rad,  only: rrtmg_sw

implicit none

contains

subroutine c_rrtmg_sw_init(cpdair) bind(c)
    real(c_double), intent(in) :: cpdair
    call rrtmg_sw_ini(cpdair)
end subroutine c_rrtmg_sw_init

subroutine c_mcica_subcol_sw &
           (iplon, ncol, nlay, icld, permuteseed, irng, play, &
            cldfrac, ciwp, clwp, rei, rel, tauc, ssac, asmc, fsfc, &
            cldfmcl, ciwpmcl, clwpmcl, reicmcl, relqmcl, &
            taucmcl, ssacmcl, asmcmcl, fsfcmcl) bind(c)
      integer(c_int), intent(in) :: iplon           ! column/longitude dimension
      integer(c_int), intent(in) :: ncol            ! number of columns
      integer(c_int), intent(in) :: nlay            ! number of model layers
      integer(c_int), intent(in) :: icld            ! clear/cloud, cloud overlap flag
      integer(c_int), intent(in) :: permuteseed     ! if the cloud generator is called multiple times,
                                                      ! permute the seed between
                                                      ! each call;
                                                      ! between calls for LW and
                                                      ! SW, recommended
                                                      ! permuteseed differs by
                                                      ! 'ngpt'
      integer(c_int), intent(inout) :: irng         ! flag for random number generator
                                                      !  0 = kissvec
                                                      !  1 = Mersenne Twister

! Atmosphere
      real(c_double), intent(in) :: play(ncol,nlay)          ! layer pressures (mb)
                                                      !    Dimensions:
                                                      !    (ncol,nlay)

! Atmosphere/clouds - cldprop
      real(c_double), intent(in) :: cldfrac(ncol,nlay)       ! layer cloud fraction
                                                      !    Dimensions:
                                                      !    (ncol,nlay)
      real(c_double), intent(in) :: tauc(ngptsw,ncol,nlay)        ! in-cloud optical depth
                                                      !    Dimensions:
                                                      !    (nbndsw,ncol,nlay)
      real(c_double), intent(in) :: ssac(ngptsw,ncol,nlay)        ! in-cloud single scattering albedo (non-delta scaled)
                                                      !    Dimensions:
                                                      !    (nbndsw,ncol,nlay)
      real(c_double), intent(in) :: asmc(ngptsw,ncol,nlay)        ! in-cloud asymmetry parameter (non-delta scaled)
                                                      !    Dimensions:
                                                      !    (nbndsw,ncol,nlay)
      real(c_double), intent(in) :: fsfc(ngptsw,ncol,nlay)        ! in-cloud forward scattering fraction (non-delta scaled)
                                                      !    Dimensions:
                                                      !    (nbndsw,ncol,nlay)
      real(c_double), intent(in) :: ciwp(ncol,nlay)          ! in-cloud ice water path
                                                      !    Dimensions:
                                                      !    (ncol,nlay)
      real(c_double), intent(in) :: clwp(ncol,nlay)          ! in-cloud liquid water path
                                                      !    Dimensions:
                                                      !    (ncol,nlay)
      real(c_double), intent(in) :: rei(ncol,nlay)           ! cloud ice particle size
                                                      !    Dimensions:
                                                      !    (ncol,nlay)
      real(c_double), intent(in) :: rel(ncol,nlay)           ! cloud liquid particle size
                                                      !    Dimensions:
                                                      !    (ncol,nlay)
      real(c_double), intent(out) :: cldfmcl(ngptsw,ncol,nlay)    ! cloud fraction [mcica]
                                                      !    Dimensions:
                                                      !    (ngptsw,ncol,nlay)
      real(c_double), intent(out) :: ciwpmcl(ngptsw,ncol,nlay)    ! in-cloud ice water path [mcica]
                                                      !    Dimensions:
                                                      !    (ngptsw,ncol,nlay)
      real(c_double), intent(out) :: clwpmcl(ngptsw,ncol,nlay)    ! in-cloud liquid water path [mcica]
                                                      !    Dimensions:
                                                      !    (ngptsw,ncol,nlay)
      real(c_double), intent(out) :: relqmcl(ncol,nlay)      ! liquid particle size (microns)
                                                      !    Dimensions:
                                                      !    (ncol,nlay)
      real(c_double), intent(out) :: reicmcl(ncol,nlay)      ! ice partcle size (microns)
                                                      !    Dimensions:
                                                      !    (ncol,nlay)
      real(c_double), intent(out) :: taucmcl(ngptsw,ncol,nlay)    ! in-cloud optical depth [mcica]
                                                      !    Dimensions:
                                                      !    (ngptsw,ncol,nlay)
      real(c_double), intent(out) :: ssacmcl(ngptsw,ncol,nlay)    ! in-cloud single scattering albedo [mcica]
                                                      !    Dimensions:
                                                      !    (ngptsw,ncol,nlay)
      real(c_double), intent(out) :: asmcmcl(ngptsw,ncol,nlay)    ! in-cloud asymmetry parameter [mcica]
                                                      !    Dimensions:
                                                      !    (ngptsw,ncol,nlay)
      real(c_double), intent(out) :: fsfcmcl(ngptsw,ncol,nlay)    ! in-cloud forward scattering fraction [mcica]
                                                      !    Dimensions:
                                                      !    (ngptsw,ncol,nlay)

      call mcica_subcol_sw &
           (iplon, ncol, nlay, icld, permuteseed, irng, play, &
            cldfrac, ciwp, clwp, rei, rel, tauc, ssac, asmc, fsfc, &
            cldfmcl, ciwpmcl, clwpmcl, reicmcl, relqmcl, &
            taucmcl, ssacmcl, asmcmcl, fsfcmcl)
end subroutine c_mcica_subcol_sw

subroutine c_rrtmg_sw &
            (ncol    ,nlay    ,icld    ,iaer    , &
             play    ,plev    ,tlay    ,tlev    ,tsfc    , &
             h2ovmr  ,o3vmr   ,co2vmr  ,ch4vmr  ,n2ovmr  ,o2vmr, &
             asdir   ,asdif   ,aldir   ,aldif   , &
             coszen  ,adjes   ,dyofyr  ,scon    , &
             inflgsw ,iceflgsw,liqflgsw,cldfr   , &
             taucld  ,ssacld  ,asmcld  ,fsfcld  , &
             cicewp  ,cliqwp  ,reice   ,reliq   , &
             tauaer  ,ssaaer  ,asmaer  ,ecaer   , &
             swuflx  ,swdflx  ,swhr    ,swuflxc ,swdflxc ,swhrc) bind(c)
             
      integer(c_int), intent(in) :: ncol            ! Number of horizontal columns     
      integer(c_int), intent(in) :: nlay            ! Number of model layers
      integer(c_int), intent(inout) :: icld         ! Cloud overlap method
                                                      !    0: Clear only
                                                      !    1: Random
                                                      !    2: Maximum/random
                                                      !    3: Maximum
      integer(c_int), intent(inout) :: iaer         ! Aerosol option flag
                                                      !    0: No aerosol
                                                      !    6: ECMWF method
                                                      !    10:Input aerosol optical 
                                                      !       properties

      real(c_double), intent(in) :: play(ncol,nlay)          ! Layer pressures (hPa, mb)
                                                      !    Dimensions: (ncol,nlay)
      real(c_double), intent(in) :: plev(ncol,nlay+1)          ! Interface pressures (hPa, mb)
                                                      !    Dimensions: (ncol,nlay+1)
      real(c_double), intent(in) :: tlay(ncol,nlay)          ! Layer temperatures (K)
                                                      !    Dimensions: (ncol,nlay)
      real(c_double), intent(in) :: tlev(ncol,nlay+1)          ! Interface temperatures (K)
                                                      !    Dimensions: (ncol,nlay+1)
      real(c_double), intent(in) :: tsfc(ncol)            ! Surface temperature (K)
                                                      !    Dimensions: (ncol)
      real(c_double), intent(in) :: h2ovmr(ncol,nlay)        ! H2O volume mixing ratio
                                                      !    Dimensions: (ncol,nlay)
      real(c_double), intent(in) :: o3vmr(ncol,nlay)         ! O3 volume mixing ratio
                                                      !    Dimensions: (ncol,nlay)
      real(c_double), intent(in) :: co2vmr(ncol,nlay)        ! CO2 volume mixing ratio
                                                      !    Dimensions: (ncol,nlay)
      real(c_double), intent(in) :: ch4vmr(ncol,nlay)        ! Methane volume mixing ratio
                                                      !    Dimensions: (ncol,nlay)
      real(c_double), intent(in) :: n2ovmr(ncol,nlay)        ! Nitrous oxide volume mixing ratio
                                                      !    Dimensions: (ncol,nlay)
      real(c_double), intent(in) :: o2vmr(ncol,nlay)         ! Oxygen volume mixing ratio
                                                      !    Dimensions: (ncol,nlay)
      real(c_double), intent(in) :: asdir(ncol)           ! UV/vis surface albedo direct rad
                                                      !    Dimensions: (ncol)
      real(c_double), intent(in) :: aldir(ncol)           ! Near-IR surface albedo direct rad
                                                      !    Dimensions: (ncol)
      real(c_double), intent(in) :: asdif(ncol)           ! UV/vis surface albedo: diffuse rad
                                                      !    Dimensions: (ncol)
      real(c_double), intent(in) :: aldif(ncol)           ! Near-IR surface albedo: diffuse rad
                                                      !    Dimensions: (ncol)

      integer(c_int), intent(in) :: dyofyr          ! Day of the year (used to get Earth/Sun
                                                      !  distance if adjflx not provided)
      real(c_double), intent(in) :: adjes              ! Flux adjustment for Earth/Sun distance
      real(c_double), intent(in) :: coszen(ncol)          ! Cosine of solar zenith angle
                                                      !    Dimensions: (ncol)
      real(c_double), intent(in) :: scon               ! Solar constant (W/m2)

      integer(c_int), intent(in) :: inflgsw         ! Flag for cloud optical properties
      integer(c_int), intent(in) :: iceflgsw        ! Flag for ice particle specification
      integer(c_int), intent(in) :: liqflgsw        ! Flag for liquid droplet specification

      real(c_double), intent(in) :: cldfr(ngptsw, ncol,nlay)         ! Cloud fraction
                                                      !    Dimensions: (ncol,nlay)
      real(c_double), intent(in) :: taucld(ngptsw,ncol,nlay)      ! In-cloud optical depth
                                                      !    Dimensions: (nbndsw,ncol,nlay)
      real(c_double), intent(in) :: ssacld(ngptsw,ncol,nlay)      ! In-cloud single scattering albedo
                                                      !    Dimensions: (nbndsw,ncol,nlay)
      real(c_double), intent(in) :: asmcld(ngptsw,ncol,nlay)      ! In-cloud asymmetry parameter
                                                      !    Dimensions: (nbndsw,ncol,nlay)
      real(c_double), intent(in) :: fsfcld(ngptsw,ncol,nlay)      ! In-cloud forward scattering fraction
                                                      !    Dimensions: (nbndsw,ncol,nlay)
      real(c_double), intent(in) :: cicewp(ngptsw, ncol,nlay)        ! In-cloud ice water path (g/m2)
                                                      !    Dimensions: (ncol,nlay)
      real(c_double), intent(in) :: cliqwp(ngptsw,ncol,nlay)        ! In-cloud liquid water path (g/m2)
                                                      !    Dimensions: (ncol,nlay)
      real(c_double), intent(in) :: reice(ncol,nlay)         ! Cloud ice effective radius (microns)
                                                      !    Dimensions: (ncol,nlay)
                                                      ! specific definition of reice depends on setting of iceflgsw:
                                                      ! iceflgsw = 0: (inactive)
                                                      !              
                                                      ! iceflgsw = 1: ice effective radius, r_ec, (Ebert and Curry, 1992),
                                                      !               r_ec range is limited to 13.0 to 130.0 microns
                                                      ! iceflgsw = 2: ice effective radius, r_k, (Key, Streamer Ref. Manual, 1996)
                                                      !               r_k range is limited to 5.0 to 131.0 microns
                                                      ! iceflgsw = 3: generalized effective size, dge, (Fu, 1996),
                                                      !               dge range is limited to 5.0 to 140.0 microns
                                                      !               [dge = 1.0315 * r_ec]
      real(c_double), intent(in) :: reliq(ncol,nlay)         ! Cloud water drop effective radius (microns)
                                                      !    Dimensions: (ncol,nlay)
      real(c_double), intent(in) :: tauaer(ncol,nlay,nbndsw)      ! Aerosol optical depth (iaer=10 only)
                                                      !    Dimensions: (ncol,nlay,nbndsw)
                                                      ! (non-delta scaled)      
      real(c_double), intent(in) :: ssaaer(ncol,nlay,nbndsw)      ! Aerosol single scattering albedo (iaer=10 only)
                                                      !    Dimensions: (ncol,nlay,nbndsw)
                                                      ! (non-delta scaled)      
      real(c_double), intent(in) :: asmaer(ncol,nlay,nbndsw)      ! Aerosol asymmetry parameter (iaer=10 only)
                                                      !    Dimensions: (ncol,nlay,nbndsw)
                                                      ! (non-delta scaled)      
      real(c_double), intent(in) :: ecaer(ncol,nlay,naerec)       ! Aerosol optical depth at 0.55 micron (iaer=6 only)
                                                      !    Dimensions: (ncol,nlay,naerec)
                                                      ! (non-delta scaled)      

! ----- Output -----

      real(c_double), intent(out) :: swuflx(ncol,nlay+1)       ! Total sky shortwave upward flux (W/m2)
                                                      !    Dimensions: (ncol,nlay+1)
      real(c_double), intent(out) :: swdflx(ncol,nlay+1)       ! Total sky shortwave downward flux (W/m2)
                                                      !    Dimensions: (ncol,nlay+1)
      real(c_double), intent(out) :: swhr(ncol,nlay)         ! Total sky shortwave radiative heating rate (K/d)
                                                      !    Dimensions: (ncol,nlay)
      real(c_double), intent(out) :: swuflxc(ncol,nlay+1)      ! Clear sky shortwave upward flux (W/m2)
                                                      !    Dimensions: (ncol,nlay+1)
      real(c_double), intent(out) :: swdflxc(ncol,nlay+1)      ! Clear sky shortwave downward flux (W/m2)
                                                      !    Dimensions: (ncol,nlay+1)
      real(c_double), intent(out) :: swhrc(ncol,nlay)        ! Clear sky shortwave radiative heating rate (K/d)
                                                      !    Dimensions: (ncol,nlay)
                                                      
    
    
    call rrtmg_sw &
            (ncol    ,nlay    ,icld    ,iaer    , &    ! idelm added by ZTAN
             play    ,plev    ,tlay    ,tlev    ,tsfc    , &
             h2ovmr  ,o3vmr   ,co2vmr  ,ch4vmr  ,n2ovmr  ,o2vmr, &
             asdir   ,asdif   ,aldir   ,aldif   , &
             coszen  ,adjes   ,dyofyr  ,scon    , &
             inflgsw ,iceflgsw,liqflgsw,cldfr   , &
             taucld  ,ssacld  ,asmcld  ,fsfcld  , &
             cicewp  ,cliqwp  ,reice   ,reliq   , &
             tauaer  ,ssaaer  ,asmaer  ,ecaer   , &
             swuflx  ,swdflx  ,swhr    ,swuflxc ,swdflxc ,swhrc)
end subroutine c_rrtmg_sw


end module
