#!python
#cython: boundscheck=True
#cython: wraparound=False
#cython: initializedcheck=True
#cython: cdivision=False

import numpy as np
include "parameters.pxi"
import cython
from Grid cimport Grid
from ReferenceState cimport ReferenceState
from NetCDFIO cimport  NetCDFIO_Stats
from TimeStepping cimport TimeStepping
from Variables cimport GridMeanVariables, VariablePrognostic
from forcing_functions cimport  convert_forcing_entropy, convert_forcing_thetal
from libc.math cimport cbrt, sqrt, log, fabs,atan, exp, fmax, pow, fmin
import netCDF4 as nc
from scipy.interpolate import interp2d

cdef class RadiationBase:
    cdef:
        double [:] dTdt
        double [:] dqtdt
        double (*convert_forcing_prog_fp)(double p0, double qt, double qv, double T,
                                          double qt_tendency, double T_tendency) nogil
        Grid Gr
        ReferenceState Ref

    cpdef initialize(self, ReferenceState Ref, Grid Gr, GridMeanVariables GMV, TimeStepping TS)
    cpdef update(self, ReferenceState Ref, Grid Gr, GridMeanVariables GMV, TimeStepping TS)
    cpdef initialize_io(self, NetCDFIO_Stats Stats)
    cpdef io(self, NetCDFIO_Stats Stats)

cdef class RadiationNone(RadiationBase):
    cpdef initialize(self, ReferenceState Ref, Grid Gr, GridMeanVariables GMV, TimeStepping TS)
    cpdef update(self, ReferenceState Ref, Grid Gr, GridMeanVariables GMV, TimeStepping TS)
    cpdef initialize_io(self, NetCDFIO_Stats Stats)
    cpdef io(self, NetCDFIO_Stats Stats)

cdef class RadiationTRMM_LBA(RadiationBase):
    cdef:
        double [:] rad_time
        double [:,:] rad

    cpdef initialize(self, ReferenceState Ref, Grid Gr, GridMeanVariables GMV, TimeStepping TS)
    cpdef update(self, ReferenceState Ref, Grid Gr, GridMeanVariables GMV, TimeStepping TS)
    cpdef initialize_io(self, NetCDFIO_Stats Stats)
    cpdef io(self, NetCDFIO_Stats Stats)


cdef class RadiationDYCOMS_RF01(RadiationBase):
    cdef:
        double alpha_z
        double kappa
        double F0
        double F1
        double divergence
        double [:] f_rad # radiative flux at cell edges
    cpdef initialize(self, ReferenceState Ref, Grid Gr, GridMeanVariables GMV, TimeStepping TS)
    cpdef calculate_radiation(self, ReferenceState Ref, Grid Gr, GridMeanVariables GMV, TimeStepping TS)
    cpdef update(self, ReferenceState Ref, Grid Gr, GridMeanVariables GMV, TimeStepping TS)
    cpdef initialize_io(self, NetCDFIO_Stats Stats)
    cpdef io(self, NetCDFIO_Stats Stats)

cdef class RadiationLES(RadiationBase):
    cdef:
        double [:,:] dtdt_rad
    cpdef initialize(self, ReferenceState Ref, Grid Gr, GridMeanVariables GMV, TimeStepping TS)
    cpdef update(self, ReferenceState Ref, Grid Gr, GridMeanVariables GMV, TimeStepping TS)
    cpdef initialize_io(self, NetCDFIO_Stats Stats)
    cpdef io(self, NetCDFIO_Stats Stats)
    

cdef class RadiationRRTM(RadiationBase):
    cdef:
        double [:,:] dtdt_rad

        double srf_lw_down
        double srf_lw_up
        double srf_sw_down
        double srf_sw_up
        str profile_name
        bint read_file
        str file
        int site
        Py_ssize_t n_buffer
        double stretch_factor
        double patch_pressure
        double co2_factor
        double h2o_factor
        int dyofyr
        double scon
        double adjes
        double toa_sw
        double coszen
        double adif
        double adir
        bint uniform_reliq
        double radiation_frequency
        double next_radiation_calculate
        double [:] heating_rate
        public double [:] net_lw_flux
        Py_ssize_t n_ext
        double [:] p_ext
        double [:] t_ext
        double [:] rv_ext
        double [:] p_full
        double [:] pi_full
        double [:] o3vmr
        double [:] co2vmr
        double [:] ch4vmr
        double [:] n2ovmr
        double [:] o2vmr
        double [:] cfc11vmr
        double [:] cfc12vmr
        double [:] cfc22vmr
        double [:] ccl4vmr
        double IsdacCC_dT
        str out_file

    cpdef initialize(self, ReferenceState Ref, Grid Gr, GridMeanVariables GMV, TimeStepping TS)
    cpdef update(self, ReferenceState Ref, Grid Gr, GridMeanVariables GMV, TimeStepping TS)
    cpdef initialize_io(self, NetCDFIO_Stats Stats)
    cpdef io(self, NetCDFIO_Stats Stats)