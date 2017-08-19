import numpy as np
import pylab as plt
include "parameters.pxi"
import cython

from Grid cimport Grid
from Variables cimport GridMeanVariables
from ReferenceState cimport ReferenceState
from TimeStepping cimport  TimeStepping
cimport Surface
cimport Forcing
from NetCDFIO cimport NetCDFIO_Stats
from thermodynamic_functions cimport exner_c, t_to_entropy_c, latent_heat, cpm_c, thetali_c, pv_star, theta_rho_c
import math
from libc.math cimport sqrt, log, fabs,atan, exp, fmax
import netCDF4 as nc # yair added this to read Rico fluxes from pycles

def CasesFactory(namelist, paramlist):
    if namelist['meta']['casename'] == 'Soares':
        return Soares(paramlist)
    elif namelist['meta']['casename'] == 'Bomex':
        return Bomex(paramlist)
    elif namelist['meta']['casename'] == 'Bomex_pulse':
        return Bomex_pulse(paramlist)
    elif namelist['meta']['casename'] == 'Rico':
        return Rico(paramlist)
    elif namelist['meta']['casename'] == 'TRMM_LBA':
        return TRMM_LBA(paramlist)
    elif namelist['meta']['casename'] == 'ARM_SGP':
        return ARM_SGP(paramlist)
    elif namelist['meta']['casename'] == 'SCMS':
        return SCMS(paramlist)
    elif namelist['meta']['casename'] == 'GATE_III':
        return GATE_III(paramlist)
    else:
        print('case not recognized')
        print('yair')
    return


cdef class CasesBase:
    def __init__(self, paramlist):
        return
    cpdef initialize_reference(self, Grid Gr, ReferenceState Ref, NetCDFIO_Stats Stats):
        return
    cpdef initialize_profiles(self, Grid Gr, GridMeanVariables GMV, ReferenceState Ref):
        return
    cpdef initialize_surface(self, Grid Gr, ReferenceState Ref ):
        return
    cpdef initialize_forcing(self, Grid Gr,  ReferenceState Ref, GridMeanVariables GMV):
        return
    cpdef initialize_io(self, NetCDFIO_Stats Stats):
        Stats.add_ts('Tsurface')
        Stats.add_ts('shf')
        Stats.add_ts('lhf')
        Stats.add_ts('ustar')
        return
    cpdef io(self, NetCDFIO_Stats Stats):
        Stats.write_ts('Tsurface', self.Sur.Tsurface)
        Stats.write_ts('shf', self.Sur.shf)
        Stats.write_ts('lhf', self.Sur.lhf)
        Stats.write_ts('ustar', self.Sur.ustar)
        return
    cpdef update_surface(self, GridMeanVariables GMV, TimeStepping TS):
        return
    cpdef update_forcing(self, GridMeanVariables GMV, Grid Gr, ReferenceState Ref, TimeStepping TS):
        return


cdef class Soares(CasesBase):
    def __init__(self, paramlist):
        self.casename = 'Soares2004'
        self.Sur = Surface.SurfaceFixedFlux(paramlist)
        self.Fo = Forcing.ForcingNone()
        self.inversion_option = 'critical_Ri'
        return
    cpdef initialize_reference(self, Grid Gr, ReferenceState Ref, NetCDFIO_Stats Stats):
        Ref.Pg = 1000.0 * 100.0
        Ref.qtg = 4.5e-3
        Ref.Tg = 300.0
        Ref.initialize(Gr, Stats)
        return
    cpdef initialize_profiles(self, Grid Gr, GridMeanVariables GMV, ReferenceState Ref):
        cdef:
            double [:] theta = np.zeros((Gr.nzg,),dtype=np.double, order='c')
            double ql = 0.0, qi = 0.0

        for k in xrange(Gr.gw, Gr.nzg-Gr.gw):
            if Gr.z_half[k] <= 1350.0:
                GMV.QT.values[k] = 5.0e-3 - 3.7e-4* Gr.z_half[k]/1000.0
                theta[k] = 300.0

            else:
                GMV.QT.values[k] = 5.0e-3 - 3.7e-4 * 1.35 - 9.4e-4 * (Gr.z_half[k]-1350.0)/1000.0
                theta[k] = 300.0 + 2.0 * (Gr.z_half[k]-1350.0)/1000.0
            GMV.U.values[k] = 0.01

        # if GMV.use_tke:
        #     for k in xrange(Gr.gw, Gr.nzg-Gr.gw):
        #         if Gr.z_half[k] <= 1350.0:
        #             GMV.TKE.values[k] = 0.5 - 0.5/1350.0 * Gr.z_half[k]
        #         else:
        #             GMV.TKE.values[k] = 0.0
        #     GMV.TKE.set_bcs(Gr)

        GMV.U.set_bcs(Gr)
        GMV.QT.set_bcs(Gr)



        if GMV.H.name == 'thetal':
            for k in xrange(Gr.gw,Gr.nzg-Gr.gw):
                GMV.H.values[k] = theta[k]
                GMV.T.values[k] =  theta[k] * exner_c(Ref.p0_half[k])
                GMV.THL.values[k] = theta[k]
        elif GMV.H.name == 's':
            for k in xrange(Gr.gw,Gr.nzg-Gr.gw):
                GMV.T.values[k] = theta[k] * exner_c(Ref.p0_half[k])
                GMV.H.values[k] = t_to_entropy_c(Ref.p0_half[k],GMV.T.values[k],
                                                 GMV.QT.values[k], ql, qi)
                GMV.THL.values[k] = thetali_c(Ref.p0_half[k],GMV.T.values[k],
                                                 GMV.QT.values[k], ql, qi, latent_heat(GMV.T.values[k]))

        GMV.H.set_bcs(Gr)
        GMV.T.set_bcs(Gr)
        GMV.satadjust()

        return

    cpdef initialize_surface(self, Grid Gr, ReferenceState Ref ):
        self.Sur.zrough = 1.0e-4
        self.Sur.Tsurface = 300.0
        self.Sur.qsurface = 5e-3
        self.Sur.lhf = 2.5e-5 * Ref.rho0[Gr.gw -1] * latent_heat(self.Sur.Tsurface)
        self.Sur.shf = 6.0e-2 * cpm_c(self.Sur.qsurface) * Ref.rho0[Gr.gw-1]
        self.Sur.ustar_fixed = False
        self.Sur.Gr = Gr
        self.Sur.Ref = Ref
        self.Sur.bflux = g * ( 6.0e-2/self.Sur.Tsurface + (eps_vi -1.0)* 2.5e-5)
        self.Sur.initialize()

        return
    cpdef initialize_forcing(self, Grid Gr, ReferenceState Ref, GridMeanVariables GMV):
        self.Fo.Gr = Gr
        self.Fo.Ref = Ref
        return

    cpdef initialize_io(self, NetCDFIO_Stats Stats):
        CasesBase.initialize_io(self, Stats)
        return
    cpdef io(self, NetCDFIO_Stats Stats):
        CasesBase.io(self, Stats)
        return

    cpdef update_surface(self, GridMeanVariables GMV, TimeStepping TS):
        self.Sur.update(GMV)
        return
    cpdef update_forcing(self, GridMeanVariables GMV, Grid Gr, ReferenceState Ref, TimeStepping TS):
        return

cdef class Bomex(CasesBase):
    def __init__(self, paramlist):
        self.casename = 'Bomex'
        self.Sur = Surface.SurfaceFixedFlux(paramlist)
        self.Fo = Forcing.ForcingStandard()
        self.inversion_option = 'critical_Ri'
        self.Fo.apply_coriolis = True
        self.Fo.coriolis_param = 0.376e-4 # s^{-1}
        return
    cpdef initialize_reference(self, Grid Gr, ReferenceState Ref, NetCDFIO_Stats Stats):
        Ref.Pg = 1.015e5  #Pressure at ground
        Ref.Tg = 300.4  #Temperature at ground
        Ref.qtg = 0.02245   #Total water mixing ratio at surface
        Ref.initialize(Gr, Stats)
        return
    cpdef initialize_profiles(self, Grid Gr, GridMeanVariables GMV, ReferenceState Ref):
        cdef:
            double [:] thetal = np.zeros((Gr.nzg,), dtype=np.double, order='c')
            double ql=0.0, qi =0.0 # IC of Bomex is cloud-free

        for k in xrange(Gr.gw,Gr.nzg-Gr.gw):
            #Set Thetal profile
            if Gr.z_half[k] <= 520.:
                thetal[k] = 298.7
            if Gr.z_half[k] > 520.0 and Gr.z_half[k] <= 1480.0:
                thetal[k] = 298.7 + (Gr.z_half[k] - 520)  * (302.4 - 298.7)/(1480.0 - 520.0)
            if Gr.z_half[k] > 1480.0 and Gr.z_half[k] <= 2000:
                thetal[k] = 302.4 + (Gr.z_half[k] - 1480.0) * (308.2 - 302.4)/(2000.0 - 1480.0)
            if Gr.z_half[k] > 2000.0:
                thetal[k] = 308.2 + (Gr.z_half[k] - 2000.0) * (311.85 - 308.2)/(3000.0 - 2000.0)

            #Set qt profile
            if Gr.z_half[k] <= 520:
                GMV.QT.values[k] = (17.0 + (Gr.z_half[k]) * (16.3-17.0)/520.0)/1000.0
            if Gr.z_half[k] > 520.0 and Gr.z_half[k] <= 1480.0:
                GMV.QT.values[k] = (16.3 + (Gr.z_half[k] - 520.0)*(10.7 - 16.3)/(1480.0 - 520.0))/1000.0
            if Gr.z_half[k] > 1480.0 and Gr.z_half[k] <= 2000.0:
                GMV.QT.values[k] = (10.7 + (Gr.z_half[k] - 1480.0) * (4.2 - 10.7)/(2000.0 - 1480.0))/1000.0
            if Gr.z_half[k] > 2000.0:
                GMV.QT.values[k] = (4.2 + (Gr.z_half[k] - 2000.0) * (3.0 - 4.2)/(3000.0  - 2000.0))/1000.0


            #Set u profile
            if Gr.z_half[k] <= 700.0:
                GMV.U.values[k] = -8.75
            if Gr.z_half[k] > 700.0:
                GMV.U.values[k] = -8.75 + (Gr.z_half[k] - 700.0) * (-4.61 - -8.75)/(3000.0 - 700.0)

        if GMV.H.name == 'thetal':
            for k in xrange(Gr.gw,Gr.nzg-Gr.gw):
                GMV.H.values[k] = thetal[k]
                GMV.T.values[k] =  thetal[k] * exner_c(Ref.p0_half[k])
                GMV.THL.values[k] = thetal[k]
        elif GMV.H.name == 's':
            for k in xrange(Gr.gw,Gr.nzg-Gr.gw):
                GMV.T.values[k] = thetal[k] * exner_c(Ref.p0_half[k])
                GMV.H.values[k] = t_to_entropy_c(Ref.p0_half[k],GMV.T.values[k],
                                                 GMV.QT.values[k], ql, qi)
                GMV.THL.values[k] = thetali_c(Ref.p0_half[k],GMV.T.values[k],
                                                 GMV.QT.values[k], ql, qi, latent_heat(GMV.T.values[k]))

        GMV.U.set_bcs(Gr)
        GMV.QT.set_bcs(Gr)
        GMV.H.set_bcs(Gr)
        GMV.T.set_bcs(Gr)
        GMV.satadjust()

        return
    cpdef initialize_surface(self, Grid Gr, ReferenceState Ref):
        self.Sur.zrough = 1.0e-4 # not actually used, but initialized to reasonable value
        self.Sur.Tsurface = 299.1 * exner_c(Ref.Pg)
        self.Sur.qsurface = 22.45e-3 # kg/kg
        self.Sur.lhf = 5.2e-5 * Ref.rho0[Gr.gw -1] * latent_heat(self.Sur.Tsurface)
        self.Sur.shf = 8.0e-3 * cpm_c(self.Sur.qsurface) * Ref.rho0[Gr.gw-1]
        self.Sur.ustar_fixed = True
        self.Sur.ustar = 0.28 # m/s
        self.Sur.Gr = Gr
        self.Sur.Ref = Ref
        self.Sur.bflux = (g * ((8.0e-3 + (eps_vi-1.0)*(299.1 * 5.2e-5  + 22.45e-3 * 8.0e-3)) /(299.1 * (1.0 + (eps_vi-1) * 22.45e-3))))
        self.Sur.initialize()
        return
    cpdef initialize_forcing(self, Grid Gr, ReferenceState Ref, GridMeanVariables GMV):
        self.Fo.Gr = Gr
        self.Fo.Ref = Ref
        self.Fo.initialize(GMV)
        for k in xrange(Gr.gw, Gr.nzg-Gr.gw):
            # Geostrophic velocity profiles. vg = 0
            self.Fo.ug[k] = -10.0 + (1.8e-3)*Gr.z_half[k]
            # Set large-scale cooling
            if Gr.z_half[k] <= 1500.0:
                self.Fo.dTdt[k] =  (-2.0/(3600 * 24.0))  * exner_c(Ref.p0_half[k])
            else:
                self.Fo.dTdt[k] = (-2.0/(3600 * 24.0) + (Gr.z_half[k] - 1500.0)
                                    * (0.0 - -2.0/(3600 * 24.0)) / (3000.0 - 1500.0)) * exner_c(Ref.p0_half[k])
            # Set large-scale drying
            if Gr.z_half[k] <= 300.0:
                self.Fo.dqtdt[k] = -1.2e-8   #kg/(kg * s)
            if Gr.z_half[k] > 300.0 and Gr.z_half[k] <= 500.0:
                self.Fo.dqtdt[k] = -1.2e-8 + (Gr.z_half[k] - 300.0)*(0.0 - -1.2e-8)/(500.0 - 300.0) #kg/(kg * s)

            #Set large scale subsidence
            if Gr.z_half[k] <= 1500.0:
                self.Fo.subsidence[k] = 0.0 + Gr.z_half[k]*(-0.65/100.0 - 0.0)/(1500.0 - 0.0)
            if Gr.z_half[k] > 1500.0 and Gr.z_half[k] <= 2100.0:
                self.Fo.subsidence[k] = -0.65/100 + (Gr.z_half[k] - 1500.0)* (0.0 - -0.65/100.0)/(2100.0 - 1500.0)
        return

    cpdef initialize_io(self, NetCDFIO_Stats Stats):
        CasesBase.initialize_io(self, Stats)
        return
    cpdef io(self, NetCDFIO_Stats Stats):
        CasesBase.io(self,Stats)
        return
    cpdef update_surface(self, GridMeanVariables GMV, TimeStepping TS):
        self.Sur.update(GMV)
        return
    cpdef update_forcing(self, GridMeanVariables GMV, Grid Gr, ReferenceState Ref, TimeStepping TS):
        self.Fo.update(GMV)
        return

cdef class Bomex_pulse(CasesBase):
    def __init__(self, paramlist):
        self.casename = 'Bomex_pulse'
        self.Sur = Surface.SurfaceFixedFlux(paramlist)
        self.Fo = Forcing.ForcingStandard()
        self.inversion_option = 'critical_Ri'
        self.Fo.apply_coriolis = True
        self.Fo.coriolis_param = 0.376e-4 # s^{-1}
        return
    cpdef initialize_reference(self, Grid Gr, ReferenceState Ref, NetCDFIO_Stats Stats):
        Ref.Pg = 1.015e5  #Pressure at ground
        Ref.Tg = 300.4  #Temperature at ground
        Ref.qtg = 0.02245   #Total water mixing ratio at surface
        Ref.initialize(Gr, Stats)
        return
    cpdef initialize_profiles(self, Grid Gr, GridMeanVariables GMV, ReferenceState Ref):
        cdef:
            double [:] thetal = np.zeros((Gr.nzg,), dtype=np.double, order='c')
            double ql=0.0, qi =0.0 # IC of Bomex is cloud-free

        for k in xrange(Gr.gw,Gr.nzg-Gr.gw):
            #Set Thetal profile
            if Gr.z_half[k] <= 520.:
                thetal[k] = 298.7
            if Gr.z_half[k] > 520.0 and Gr.z_half[k] <= 1480.0:
                thetal[k] = 298.7 + (Gr.z_half[k] - 520)  * (302.4 - 298.7)/(1480.0 - 520.0)
            if Gr.z_half[k] > 1480.0 and Gr.z_half[k] <= 2000:
                thetal[k] = 302.4 + (Gr.z_half[k] - 1480.0) * (308.2 - 302.4)/(2000.0 - 1480.0)
            if Gr.z_half[k] > 2000.0:
                thetal[k] = 308.2 + (Gr.z_half[k] - 2000.0) * (311.85 - 308.2)/(3000.0 - 2000.0)

            #Set qt profile
            if Gr.z_half[k] <= 520:
                GMV.QT.values[k] = (17.0 + (Gr.z_half[k]) * (16.3-17.0)/520.0)/1000.0
            if Gr.z_half[k] > 520.0 and Gr.z_half[k] <= 1480.0:
                GMV.QT.values[k] = (16.3 + (Gr.z_half[k] - 520.0)*(10.7 - 16.3)/(1480.0 - 520.0))/1000.0
            if Gr.z_half[k] > 1480.0 and Gr.z_half[k] <= 2000.0:
                GMV.QT.values[k] = (10.7 + (Gr.z_half[k] - 1480.0) * (4.2 - 10.7)/(2000.0 - 1480.0))/1000.0
            if Gr.z_half[k] > 2000.0:
                GMV.QT.values[k] = (4.2 + (Gr.z_half[k] - 2000.0) * (3.0 - 4.2)/(3000.0  - 2000.0))/1000.0


            #Set u profile
            if Gr.z_half[k] <= 700.0:
                GMV.U.values[k] = 0.5
            if Gr.z_half[k] > 700.0:
                GMV.U.values[k] = 0.5

        if GMV.H.name == 'thetal':
            for k in xrange(Gr.gw,Gr.nzg-Gr.gw):
                GMV.H.values[k] = thetal[k]
                GMV.T.values[k] =  thetal[k] * exner_c(Ref.p0_half[k])
                GMV.THL.values[k] = thetal[k]
        elif GMV.H.name == 's':
            for k in xrange(Gr.gw,Gr.nzg-Gr.gw):
                GMV.T.values[k] = thetal[k] * exner_c(Ref.p0_half[k])
                GMV.H.values[k] = t_to_entropy_c(Ref.p0_half[k],GMV.T.values[k],
                                                 GMV.QT.values[k], ql, qi)
                GMV.THL.values[k] = thetali_c(Ref.p0_half[k],GMV.T.values[k],
                                                 GMV.QT.values[k], ql, qi, latent_heat(GMV.T.values[k]))

        GMV.U.set_bcs(Gr)
        GMV.QT.set_bcs(Gr)
        GMV.H.set_bcs(Gr)
        GMV.T.set_bcs(Gr)
        GMV.satadjust()

        return
    cpdef initialize_surface(self, Grid Gr, ReferenceState Ref):
        self.Sur.zrough = 1.0e-4 # not actually used, but initialized to reasonable value
        self.Sur.Tsurface = 299.1 * exner_c(Ref.Pg)
        self.Sur.qsurface = 22.45e-3 # kg/kg
        self.Sur.lhf = 45.8222333536705*2
        self.Sur.shf = 2.95600040157933*2
        self.Sur.ustar_fixed = True
        self.Sur.ustar = 0.28 # m/s
        self.Sur.Gr = Gr
        self.Sur.Ref = Ref
        self.Sur.bflux = (g * ((8.0e-3 + (eps_vi-1.0)*(299.1 * 5.2e-5  + 22.45e-3 * 8.0e-3)) /(299.1 * (1.0 + (eps_vi-1) * 22.45e-3))))
        self.Sur.initialize()
        return
    cpdef initialize_forcing(self, Grid Gr, ReferenceState Ref, GridMeanVariables GMV):
        self.Fo.Gr = Gr
        self.Fo.Ref = Ref
        self.Fo.initialize(GMV)
        for k in xrange(Gr.gw, Gr.nzg-Gr.gw):
            # Geostrophic velocity profiles. vg = 0
            self.Fo.ug[k] = 0.5
            # Set large-scale cooling
            if Gr.z_half[k] <= 1500.0:
                self.Fo.dTdt[k] =  (-2.0/(3600 * 24.0))  * exner_c(Ref.p0_half[k])
            else:
                self.Fo.dTdt[k] = (-2.0/(3600 * 24.0) + (Gr.z_half[k] - 1500.0)
                                    * (0.0 - -2.0/(3600 * 24.0)) / (3000.0 - 1500.0)) * exner_c(Ref.p0_half[k])
            # Set large-scale drying
            if Gr.z_half[k] <= 300.0:
                self.Fo.dqtdt[k] = -1.2e-8   #kg/(kg * s)
            if Gr.z_half[k] > 300.0 and Gr.z_half[k] <= 500.0:
                self.Fo.dqtdt[k] = -1.2e-8 + (Gr.z_half[k] - 300.0)*(0.0 - -1.2e-8)/(500.0 - 300.0) #kg/(kg * s)

            #Set large scale subsidence
            if Gr.z_half[k] <= 1500.0:
                self.Fo.subsidence[k] = 0.0 + Gr.z_half[k]*(-0.65/100.0 - 0.0)/(1500.0 - 0.0)
            if Gr.z_half[k] > 1500.0 and Gr.z_half[k] <= 2100.0:
                self.Fo.subsidence[k] = -0.65/100 + (Gr.z_half[k] - 1500.0)* (0.0 - -0.65/100.0)/(2100.0 - 1500.0)
        return

    cpdef initialize_io(self, NetCDFIO_Stats Stats):
        CasesBase.initialize_io(self, Stats)
        return
    cpdef io(self, NetCDFIO_Stats Stats):
        CasesBase.io(self,Stats)
        return
    cpdef update_surface(self, GridMeanVariables GMV, TimeStepping TS):
        if TS.t > 600.0:
            self.Sur.lhf = 147.1*0.0001
            self.Sur.shf = 9.5*0.0001
            self.Sur.bflux = (g * ((8.0e-3 + (eps_vi-1.0)*(299.1 * 5.2e-5  + 22.45e-3 * 8.0e-3)) /(299.1 * (1.0 + (eps_vi-1) * 22.45e-3))))
            #self.Sur.ustar_fixed = False
        print('===========> time is ',TS.t)
        print('===========> SHF is ',self.Sur.shf)
        print('===========> LHF is ',self.Sur.lhf)
        self.Sur.update(GMV)
        return
    cpdef update_forcing(self, GridMeanVariables GMV, Grid Gr, ReferenceState Ref, TimeStepping TS):
        self.Fo.update(GMV)
        return

cdef class Rico(CasesBase):
    def __init__(self, paramlist):
        self.casename = 'Rico'
        self.Sur = Surface.SurfaceFixedFlux(paramlist)
        self.Fo = Forcing.ForcingStandard()
        self.inversion_option = 'theta_rho'
        return
    cpdef initialize_reference(self, Grid Gr, ReferenceState Ref, NetCDFIO_Stats Stats):
        Ref.Pg = 1.0154e5  #Pressure at ground
        Ref.Tg = 299.8  #Temperature at ground
        pvg = pv_star(Ref.Tg)
        Ref.qtg = eps_v * pvg/(Ref.Pg - pvg)      #Total water mixing ratio at surface
        Ref.initialize(Gr, Stats)
        return
    cpdef initialize_profiles(self, Grid Gr, GridMeanVariables GMV, ReferenceState Ref):
        cdef:
            double [:] thetal = np.zeros((Gr.nzg,), dtype=np.double, order='c')
            #double ql=0.0, qi =0.0 # IC of Bomex is cloud-free

        for k in xrange(Gr.gw,Gr.nzg-Gr.gw):
            #Set Thetal profile
            if Gr.z_half[k] <= 740.0:
                thetal[k] = 297.9
                GMV.QT.values[k] =  16.0 + (13.8 - 16.0)/740.0 * Gr.z_half[k]
            else:
                thetal[k] = 297.9 + (317.0-297.9)/(4000.0-740.0)*(Gr.z_half[k] - 740.0)
                if Gr.z_half[k] > 740.0 and Gr.z_half[k] <= 3260.0:
                    GMV.QT.values[k] = 13.8 + (2.4 - 13.8)/(3260.0-740.0) * (Gr.z_half[k] - 740.0)
                else:
                    GMV.QT.values[k] = 2.4 + (1.8-2.4)/(4000.0-3260.0)*(Gr.z_half[k] - 3260.0)
            #Change units to kg/kg
            GMV.QT.values[k]/= 1000.0

            #Set u,v profile -  YAIR - should this be here or in initialize forcing
            GMV.U.values[k] =  - 9.9 + 2.0e-3 * Gr.z_half[k]
            GMV.V.values[k] =  - 3.8


        if GMV.H.name == 'thetal':
            for k in xrange(Gr.gw,Gr.nzg-Gr.gw):
                GMV.H.values[k] = thetal[k]
                GMV.T.values[k] =  thetal[k] * exner_c(Ref.p0_half[k])
                GMV.THL.values[k] = thetal[k]
        elif GMV.H.name == 's':
            for k in xrange(Gr.gw,Gr.nzg-Gr.gw):
                GMV.T.values[k] = thetal[k] * exner_c(Ref.p0_half[k])
                GMV.H.values[k] = t_to_entropy_c(Ref.p0_half[k],GMV.T.values[k],
                                                 GMV.QT.values[k], GMV.QL.values[k], 0.0)
                GMV.THL.values[k] = thetali_c(Ref.p0_half[k],GMV.T.values[k],
                                                 GMV.QT.values[k], GMV.QL.values[k], 0.0, latent_heat(GMV.T.values[k]))

        GMV.U.set_bcs(Gr)
        GMV.QT.set_bcs(Gr)
        GMV.H.set_bcs(Gr)
        GMV.T.set_bcs(Gr)
        GMV.satadjust()

        plt.figure(1)
        plt.plot(GMV.QT.values, Gr.z_half)
        plt.figure(2)
        plt.plot(GMV.H.values, Gr.z_half)
        plt.show()

        return
    cpdef initialize_surface(self, Grid Gr, ReferenceState Ref):
        self.Sur.Gr = Gr
        self.Sur.Ref = Ref
        self.Sur.zrough = 1.0e-4 # not actually used, but initialized to reasonable value
        self.Sur.Tsurface = 299.1 * exner_c(Ref.Pg)
        self.Sur.qsurface = 22.45e-3 # kg/kg
        self.Sur.zrough = 0.00015
        #self.Sur.cm = 0.001229*(log(20.0/self.Sur.zrough)/log(Gr.z_half[Gr.gw]/self.Sur.zrough))**2
        #self.Sur.ch = 0.001094*(log(20.0/self.Sur.zrough)/log(Gr.z_half[Gr.gw]/self.Sur.zrough))**2
        #self.Sur.cq = 0.001133*(log(20.0/self.Sur.zrough)/log(Gr.z_half[Gr.gw]/self.Sur.zrough))**2
        self.Sur.ustar_fixed = True
        self.Sur.ustar = 0.28 # m/s
        self.Sur.Gr = Gr
        self.Sur.Ref = Ref

        #self.Sur.bflux = (g * ((8.0e-3 + (eps_vi-1.0)*(299.1 * 5.2e-5  + 22.45e-3 * 8.0e-3)) /(299.1 * (1.0 + (eps_vi-1) * 22.45e-3))))

        #self.Sur.lhf = 5.2e-5 * Ref.rho0[Gr.gw -1] * latent_heat(self.Sur.Tsurface)
        #self.Sur.shf = 8.0e-3 * cpm_c(self.Sur.qsurface) * Ref.rho0[Gr.gw-1]
        #self.Sur.ustar_fixed = True
        #self.Sur.ustar = 0.28 # m/s

        #self.Sur.bflux = (g * ((8.0e-3 + (eps_vi-1.0)*(299.1 * 5.2e-5  + 22.45e-3 * 8.0e-3)) /(299.1 * (1.0 + (eps_vi-1) * 22.45e-3))))


        self.Sur.initialize()
        return
    cpdef initialize_forcing(self, Grid Gr, ReferenceState Ref, GridMeanVariables GMV):
        self.Fo.Gr = Gr
        self.Fo.Ref = Ref
        self.Fo.initialize(GMV)
        for k in xrange(Gr.gw, Gr.nzg-Gr.gw):
            # Set large-scale cooling
            self.Fo.dTdt[k] =  ( -2.5/86400.0 )  * exner_c(Ref.p0_half[k])
            # Set large-scale drying
            if Gr.z_half[k] <= 2980.0:
                self.Fo.dqtdt[k] = (-1.0 + 1.3456/2980.0 * self.Fo.Gr.z_half[k])/86400.0/1000.0  #g/(kg * s)
            else:
                self.Fo.dqtdt[k] = 0.3456/86400.0/1000.0 #g/(kg * s)

            #Set large scale subsidence
            if Gr.z_half[k] <= 2260.0:
                self.Fo.subsidence[k] = -(0.005/2260.0) * Gr.z_half[k]
            else:
                self.Fo.subsidence[k] =  -0.005

            #Set u,v profile
            GMV.U.values[k] =  - 9.9 + 2.0e-3 * Gr.z_half[k]
            GMV.V.values[k] =  - 3.8
        return


    cpdef initialize_io(self, NetCDFIO_Stats Stats):
        CasesBase.initialize_io(self, Stats)
        return
    cpdef io(self, NetCDFIO_Stats Stats):
        CasesBase.io(self,Stats)
        return
    cpdef update_surface(self, GridMeanVariables GMV, TimeStepping TS):
        cdef:
            double [:] t = np.zeros((865,),dtype=np.double,order='c')
            double [:] lhf = np.zeros((865,),dtype=np.double,order='c')
            double [:] shf = np.zeros((865,),dtype=np.double,order='c')

        t_in=nc.Dataset('/Users/yaircohen/Documents/PyCLES_out/Output.Rico.standard/stats/Stats.Rico.nc', 'r').groups['timeseries'].variables['t']
        lhf_in=nc.Dataset('/Users/yaircohen/Documents/PyCLES_out/Output.Rico.standard/stats/Stats.Rico.nc', 'r').groups['timeseries'].variables['lhf_surface_mean']
        shf_in=nc.Dataset('/Users/yaircohen/Documents/PyCLES_out/Output.Rico.standard/stats/Stats.Rico.nc', 'r').groups['timeseries'].variables['shf_surface_mean']
        if TS.t<100.0:
            self.Sur.lhf = lhf_in[1]
            self.Sur.shf = shf_in[1]
        elif TS.t<=86400:
            if TS.t%100.0 == 0:  # in case you step right on the data point
                self.Sur.lhf = lhf_in[TS.t/100.0]
                self.Sur.shf = shf_in[TS.t/100.0]
            else:
                self.Sur.lhf = (lhf_in[TS.t%100.0+1]-lhf_in[TS.t%100.0])/(t_in[TS.t%100.0+1]-t_in[TS.t%100.0])*TS.dt+lhf_in[TS.t%100.0]
                self.Sur.shf = (shf_in[TS.t%100.0+1]-shf_in[TS.t%100.0])/(t_in[TS.t%100.0+1]-t_in[TS.t%100.0])*TS.dt+shf_in[TS.t%100.0]
        else:
            self.Sur.lhf = lhf_in[864]
            self.Sur.shf = shf_in[864]
        #self.Sur.lhf = np.interp(TS.t,t_in,lhf_in)
        #self.Sur.shf = np.interp(TS.t,t_in,shf_in)
        self.Sur.update(GMV)

        return

    cpdef update_forcing(self, GridMeanVariables GMV, Grid Gr, ReferenceState Ref, TimeStepping TS):
        self.Fo.update(GMV)
        return


cdef class TRMM_LBA(CasesBase):
    def __init__(self, paramlist):
        self.casename = 'TRMM_LBA'
        self.Sur = Surface.SurfaceFixedFlux(paramlist)
        self.Fo = Forcing.ForcingRadiative() # it was forcing standard
        self.inversion_option = 'thetal_maxgrad'

        return
    cpdef initialize_reference(self, Grid Gr, ReferenceState Ref, NetCDFIO_Stats Stats):
        Ref.Pg = 991.3*100  #Pressure at ground
        Ref.Tg = 296.85   # surface values for reference state (RS) which outputs p0 rho0 alpha0
        pvg = pv_star(Ref.Tg)
        Ref.qtg = eps_v * pvg/(Ref.Pg - pvg)#Total water mixing ratio at surface
        Ref.initialize(Gr, Stats)
        return
    cpdef initialize_profiles(self, Grid Gr, GridMeanVariables GMV, ReferenceState Ref):
        cdef:

            double [:] p1 = np.zeros((Gr.nzg,),dtype=np.double,order='c')

        # TRMM_LBA inputs from Grabowski et al. 2004
        z_in = np.array([0.130,  0.464,  0.573,  1.100,  1.653,  2.216,  2.760,
                         3.297,  3.824,  4.327,  4.787,  5.242,  5.686,  6.131,
                         6.578,  6.996,  7.431,  7.881,  8.300,  8.718,  9.149,
                         9.611, 10.084, 10.573, 11.008, 11.460, 11.966, 12.472,
                        12.971, 13.478, 13.971, 14.443, 14.956, 15.458, 16.019,
                        16.491, 16.961, 17.442, 17.934, 18.397, 18.851, 19.331,
                        19.809, 20.321, 20.813, 21.329, 30.000]) * 1000 - 130.0 #LES z is in meters

        p_in = np.array([991.3, 954.2, 942.0, 886.9, 831.5, 778.9, 729.8,
                         684.0, 641.7, 603.2, 570.1, 538.6, 509.1, 480.4,
                         454.0, 429.6, 405.7, 382.5, 361.1, 340.9, 321.2,
                         301.2, 281.8, 263.1, 246.1, 230.1, 213.2, 197.0,
                         182.3, 167.9, 154.9, 143.0, 131.1, 119.7, 108.9,
                         100.1,  92.1,  84.6,  77.5,  71.4,  65.9,  60.7,
                          55.9,  51.3,  47.2,  43.3,  10.3]) * 100 # LES pres is in pasc

        T_in = np.array([23.70,  23.30,  22.57,  19.90,  16.91,  14.09,  11.13,
                          8.29,   5.38,   2.29,  -0.66,  -3.02,  -5.28,  -7.42,
                        -10.34, -12.69, -15.70, -19.21, -21.81, -24.73, -27.76,
                        -30.93, -34.62, -38.58, -42.30, -46.07, -50.03, -54.67,
                        -59.16, -63.60, -67.68, -70.77, -74.41, -77.51, -80.64,
                        -80.69, -80.00, -81.38, -81.17, -78.32, -74.77, -74.52,
                        -72.62, -70.87, -69.19, -66.90, -66.90]) + 273.15 # LES T is in deg K

        RH_in = np.array([98.00,  86.00,  88.56,  87.44,  86.67,  83.67,  79.56,
                          84.78,  84.78,  89.33,  94.33,  92.00,  85.22,  77.33,
                          80.11,  66.11,  72.11,  72.67,  52.22,  54.67,  51.00,
                          43.78,  40.56,  43.11,  54.78,  46.11,  42.33,  43.22,
                          45.33,  39.78,  33.78,  28.78,  24.67,  20.67,  17.67,
                          17.11,  16.22,  14.22,  13.00,  13.00,  12.22,   9.56,
                           7.78,   5.89,   4.33,   3.00,   3.00])

        u_in = np.array([0.00,   0.81,   1.17,   3.44,   3.53,   3.88,   4.09,
                         3.97,   1.22,   0.16,  -1.22,  -1.72,  -2.77,  -2.65,
                        -0.64,  -0.07,  -1.90,  -2.70,  -2.99,  -3.66,  -5.05,
                        -6.64,  -4.74,  -5.30,  -6.07,  -4.26,  -7.52,  -8.88,
                        -9.00,  -7.77,  -5.37,  -3.88,  -1.15,  -2.36,  -9.20,
                        -8.01,  -5.68,  -8.83, -14.51, -15.55, -15.36, -17.67,
                       -17.82, -18.94, -15.92, -15.32, -15.32])

        v_in = np.array([-0.40,  -3.51,  -3.88,  -4.77,  -5.28,  -5.85,  -5.60,
                         -2.67,  -1.47,   0.57,   0.89,  -0.08,   1.11,   2.15,
                          3.12,   3.22,   3.34,   1.91,   1.15,   1.01,  -0.57,
                         -0.67,   0.31,   2.97,   2.32,   2.66,   4.79,   3.40,
                          3.14,   3.93,   7.57,   2.58,   2.50,   6.44,   6.84,
                          0.19,  -2.20,  -3.60,   0.56,   6.68,   9.41,   7.03,
                          5.32,   1.14,  -0.65,   5.27,   5.27])
        # interpolate to the model grid-points

        p1 = np.interp(Gr.z_half,z_in,p_in)
        GMV.U.values = np.interp(Gr.z_half,z_in,u_in)
        GMV.V.values = np.interp(Gr.z_half,z_in,v_in)

        # get the entropy from RH, p, T

        RH = np.zeros(Gr.nzg)
        RH[Gr.gw:Gr.nzg-Gr.gw] = np.interp(Gr.z_half[Gr.gw:Gr.nzg-Gr.gw],z_in,RH_in)
        RH[0] = RH[3]
        RH[1] = RH[2]
        RH[Gr.nzg-Gr.gw+1] = RH[Gr.nzg-Gr.gw-1]

        T = np.zeros(Gr.nzg)
        T[Gr.gw:Gr.nzg-Gr.gw] = np.interp(Gr.z_half[Gr.gw:Gr.nzg-Gr.gw],z_in,T_in)
        GMV.T.values[0] = T[3]
        GMV.T.values[1] = T[2]
        GMV.T.values = T
        GMV.T.values[Gr.nzg-Gr.gw+1] = GMV.T.values[Gr.nzg-Gr.gw-1]


        theta_rho = RH*0.0
        epsi = 287.1/461.5
        cdef double PV_star # here pv_star is a function
        cdef double qv_star

        GMV.U.set_bcs(Gr)
        GMV.T.set_bcs(Gr)


        for k in xrange(Gr.gw,Gr.nzg-Gr.gw):
            PV_star = pv_star(GMV.T.values[k])
            qv_star = PV_star*epsi/(p1[k]- PV_star + epsi*PV_star*RH[k]/100.0) # eq. 37 in pressel et al and the def of RH
            qv = GMV.QT.values[k] - GMV.QL.values[k]
            GMV.QT.values[k] = qv_star*RH[k]/100.0
            if GMV.H.name == 's':
                GMV.H.values[k] = t_to_entropy_c(Ref.p0_half[k],GMV.T.values[k],
                                                GMV.QT.values[k], 0.0, 0.0)
            elif GMV.H.name == 'thetal':
                 GMV.H.values[k] = thetali_c(Ref.p0_half[k],GMV.T.values[k],
                                                GMV.QT.values[k], 0.0, 0.0, latent_heat(GMV.T.values[k]))

            GMV.THL.values[k] = thetali_c(Ref.p0_half[k],GMV.T.values[k],
                                                GMV.QT.values[k], 0.0, 0.0, latent_heat(GMV.T.values[k]))
            theta_rho[k] = theta_rho_c(Ref.p0_half[k], GMV.T.values[k], GMV.QT.values[k], qv)

        GMV.QT.set_bcs(Gr)
        GMV.H.set_bcs(Gr)
        GMV.satadjust()


        plt.figure(1)
        plt.plot(GMV.QT.values, Gr.z_half)
        plt.figure(2)
        plt.plot(GMV.H.values, Gr.z_half)
        plt.show()

        return
    cpdef initialize_surface(self, Grid Gr, ReferenceState Ref):
        self.Sur.zrough = 1.0e-4 # not actually used, but initialized to reasonable value
        self.Sur.Tsurface = (273.15+23) * exner_c(Ref.Pg)
        self.Sur.qsurface = 22.45e-3 # kg/kg
        self.Sur.lhf = 5.2e-5 * Ref.rho0[Gr.gw -1] * latent_heat(self.Sur.Tsurface)
        self.Sur.shf = 8.0e-3 * cpm_c(self.Sur.qsurface) * Ref.rho0[Gr.gw-1]
        #self.Sur.ustar_fixed = True # Yair ?
        #self.Sur.ustar = 0.0 # Yair ?
        self.Sur.Gr = Gr
        self.Sur.Ref = Ref
        # yair - this was just compied from Bomex
        #self.Sur.bflux = (g * ((8.0e-3 + (eps_vi-1.0)*(299.1 * 5.2e-5  + 22.45e-3 * 8.0e-3)) /(299.1 * (1.0 + (eps_vi-1) * 22.45e-3))))
        self.Sur.initialize()

        return
    cpdef initialize_forcing(self, Grid Gr, ReferenceState Ref, GridMeanVariables GMV):
        self.Fo.Gr = Gr
        self.Fo.Ref = Ref
        self.Fo.initialize(GMV)
        # only radiative forcing
        self.Fo.subsidence = np.zeros(Gr.nzg, dtype=np.double)
        #self.Fo.rad = np.zeros(Gr.nzg, dtype=np.double)
        self.Fo.rad_cool = np.zeros(Gr.nzg, dtype=np.double)
        self.Fo.subsidence = np.zeros(Gr.nzg, dtype=np.double)
        self.Fo.rad_time     = np.linspace(10,360,36)*60
        # radiation time is 10min : 10:min :360min
        self.Fo.z_in         = np.array([42.5, 200.92, 456.28, 743, 1061.08, 1410.52, 1791.32, 2203.48, 2647,
                                      3121.88, 3628.12, 4165.72, 4734.68, 5335, 5966.68, 6629.72, 7324.12,
                                      8049.88, 8807, 9595.48, 10415.32, 11266.52, 12149.08, 13063, 14008.28,
                                      14984.92, 15992.92, 17032.28, 18103, 19205.08, 20338.52, 21503.32, 22699.48])
        # a[i,j] - here i is the number of vector bounded by [] which corresponds to time, j is the number of element in each vector that corresponds to height
        self.Fo.rad_in   = np.array([[-1.386, -1.927, -2.089, -1.969, -1.805, -1.585, -1.406, -1.317, -1.188, -1.106, -1.103, -1.025,
                              -0.955, -1.045, -1.144, -1.119, -1.068, -1.092, -1.196, -1.253, -1.266, -1.306,  -0.95,  0.122,
                               0.255,  0.258,  0.322,  0.135,      0,      0,      0,      0,      0],
                             [ -1.23, -1.824, -2.011, -1.895, -1.729, -1.508, -1.331, -1.241, -1.109, -1.024, -1.018,  -0.94,
                              -0.867, -0.953, -1.046, -1.018, -0.972, -1.006, -1.119, -1.187, -1.209, -1.259, -0.919,  0.122,
                               0.264,  0.262,  0.326,  0.137,      0,      0,      0,      0,     0],
                             [-1.043, -1.692, -1.906, -1.796,  -1.63,  -1.41, -1.233, -1.142,  -1.01,  -0.92, -0.911, -0.829,
                              -0.754, -0.837, -0.923,  -0.89, -0.847, -0.895, -1.021, -1.101, -1.138, -1.201,  -0.88,  0.131,
                               0.286,  0.259,  0.332,   0.14,      0,      0,      0,      0,      0],
                             [-0.944, -1.613, -1.832,  -1.72, -1.555, -1.339, -1.163, -1.068, -0.935, -0.846, -0.835,  -0.75,
                              -0.673, -0.751, -0.833, -0.798,  -0.76, -0.817, -0.952, -1.042, -1.088, -1.159, -0.853,  0.138,
                               0.291,  0.265,  0.348,  0.136,      0,      0,      0,      0,      0],
                             [-0.833, -1.526, -1.757, -1.648, -1.485,  -1.27, -1.093, -0.998, -0.867, -0.778, -0.761, -0.672,
                              -0.594, -0.671, -0.748, -0.709, -0.676, -0.742, -0.887, -0.986, -1.041, -1.119, -0.825,  0.143,
                               0.296,  0.271,  0.351,  0.138,      0,      0,      0,      0,      0],
                             [-0.719, -1.425, -1.657,  -1.55, -1.392, -1.179, -1.003, -0.909, -0.778, -0.688, -0.667, -0.573,
                              -0.492, -0.566, -0.639, -0.596, -0.568, -0.647, -0.804, -0.914, -0.981,  -1.07, -0.793,  0.151,
                               0.303,  0.279,  0.355,  0.141,      0,      0,      0,      0,      0],
                             [-0.724, -1.374, -1.585, -1.482, -1.328, -1.116, -0.936, -0.842, -0.715, -0.624, -0.598, -0.503,
                              -0.421, -0.494, -0.561, -0.514,  -0.49,  -0.58, -0.745, -0.863, -0.938, -1.035, -0.764,  0.171,
                               0.291,  0.284,  0.358,  0.144,      0,      0,      0,      0,      0],
                             [-0.587,  -1.28, -1.513, -1.416, -1.264, -1.052, -0.874, -0.781, -0.655, -0.561, -0.532, -0.436,
                              -0.354, -0.424, -0.485, -0.435, -0.417, -0.517, -0.691, -0.817, -0.898,     -1,  -0.74,  0.176,
                               0.297,  0.289,   0.36,  0.146,      0,      0,      0,      0,      0],
                             [-0.506, -1.194, -1.426, -1.332, -1.182, -0.972, -0.795, -0.704, -0.578,  -0.48, -0.445, -0.347,
                              -0.267, -0.336, -0.391, -0.337, -0.325, -0.436,  -0.62, -0.756, -0.847,  -0.96, -0.714,   0.18,
                               0.305,  0.317,  0.348,  0.158,      0,      0,      0,      0,      0],
                             [-0.472,  -1.14, -1.364, -1.271, -1.123, -0.914, -0.738, -0.649, -0.522, -0.422, -0.386, -0.287,
                              -0.207, -0.273, -0.322, -0.267,  -0.26, -0.379, -0.569, -0.712, -0.811, -0.931, -0.696,  0.183,
                               0.311,   0.32,  0.351,   0.16,      0,      0,      0,      0,     0],
                             [-0.448, -1.091, -1.305, -1.214, -1.068, -0.858, -0.682, -0.594, -0.469, -0.368, -0.329, -0.229,
                              -0.149, -0.213, -0.257,   -0.2, -0.199, -0.327, -0.523, -0.668, -0.774, -0.903, -0.678,  0.186,
                               0.315,  0.323,  0.355,  0.162,      0,      0,      0,      0,      0],
                             [-0.405, -1.025, -1.228, -1.139, -0.996, -0.789, -0.615, -0.527, -0.402,   -0.3, -0.256, -0.156,
                              -0.077, -0.136, -0.173, -0.115, -0.121, -0.259, -0.463, -0.617, -0.732, -0.869, -0.656,   0.19,
                               0.322,  0.326,  0.359,  0.164,      0,      0,      0,      0,      0],
                             [-0.391, -0.983, -1.174, -1.085, -0.945, -0.739, -0.566, -0.478, -0.354, -0.251, -0.205, -0.105,
                              -0.027, -0.082, -0.114, -0.056, -0.069, -0.213,  -0.42, -0.579, -0.699,  -0.84, -0.642,  0.173,
                               0.327,  0.329,  0.362,  0.165,      0,      0,      0,      0,      0],
                             [-0.385, -0.946, -1.121, -1.032, -0.898, -0.695, -0.523, -0.434, -0.307, -0.203, -0.157, -0.057,
                               0.021, -0.031, -0.059, -0.001, -0.018, -0.168, -0.381, -0.546, -0.672, -0.819, -0.629,  0.176,
                               0.332,  0.332,  0.364,  0.166,      0,      0,      0,      0,      0],
                             [-0.383, -0.904, -1.063, -0.972, -0.834, -0.632, -0.464, -0.378, -0.251, -0.144, -0.096,  0.001,
                               0.079,  0.032,  0.011,  0.069,  0.044, -0.113, -0.332, -0.504, -0.637, -0.791, -0.611,  0.181,
                               0.338,  0.335,  0.367,  0.167,      0,      0,      0,      0,      0],
                             [-0.391, -0.873, -1.016, -0.929, -0.794, -0.591, -0.423, -0.337, -0.212, -0.104, -0.056,  0.043,
                               0.121,  0.077,  0.058,  0.117,  0.088, -0.075, -0.298, -0.475, -0.613, -0.772, -0.599,  0.183,
                               0.342,  0.337,   0.37,  0.168,      0,      0,      0,      0,      0],
                             [-0.359, -0.836, -0.976, -0.888, -0.755, -0.554, -0.386,   -0.3, -0.175, -0.067, -0.018,  0.081,
                                0.16,  0.119,  0.103,  0.161,  0.129, -0.039, -0.266, -0.448, -0.591, -0.755, -0.587,  0.187,
                               0.345,  0.339,  0.372,  0.169,      0,      0,      0,      0,     0],
                             [-0.328, -0.792, -0.928, -0.842, -0.709, -0.508, -0.341, -0.256, -0.131, -0.022,  0.029,  0.128,
                               0.208,   0.17,  0.158,  0.216,  0.179,  0.005, -0.228, -0.415, -0.564, -0.733, -0.573,   0.19,
                               0.384,  0.313,  0.375,   0.17,      0,      0,      0,      0,      0],
                             [-0.324, -0.767, -0.893, -0.807, -0.676, -0.476,  -0.31, -0.225, -0.101,  0.008,   0.06,  0.159,
                               0.239,  0.204,  0.195,  0.252,  0.212,  0.034, -0.203, -0.394, -0.546, -0.719, -0.564,  0.192,
                               0.386,  0.315,  0.377,  0.171,      0,      0,      0,      0,      0],
                             [ -0.31,  -0.74,  -0.86, -0.775, -0.647, -0.449, -0.283, -0.197, -0.073,  0.036,  0.089,  0.188,
                               0.269,  0.235,  0.229,  0.285,  0.242,  0.061, -0.179, -0.374,  -0.53, -0.706, -0.556,  0.194,
                               0.388,  0.317,  0.402,  0.158,      0,      0,      0,      0,      0],
                             [-0.244, -0.694, -0.818,  -0.73, -0.605, -0.415, -0.252, -0.163, -0.037,  0.072,  0.122,   0.22,
                               0.303,  0.273,  0.269,  0.324,  0.277,  0.093, -0.152,  -0.35,  -0.51, -0.691, -0.546,  0.196,
                               0.39,   0.32,  0.403,  0.159,      0,      0,      0,      0,      0],
                             [-0.284, -0.701, -0.803, -0.701, -0.568, -0.381, -0.225, -0.142, -0.017,  0.092,  0.143,  0.242,
                               0.325,  0.298,  0.295,   0.35,    0.3,  0.112, -0.134, -0.334, -0.497,  -0.68,  -0.54,  0.198,
                               0.392,  0.321,  0.404,   0.16,      0,      0,      0,      0,      0],
                             [-0.281, -0.686, -0.783,  -0.68, -0.547, -0.359, -0.202, -0.119,  0.005,  0.112,  0.163,  0.261,
                               0.345,  0.321,  0.319,  0.371,  0.319,   0.13, -0.118, -0.321, -0.486, -0.671, -0.534,  0.199,
                               0.393,  0.323,  0.405,  0.161,      0,      0,      0,      0,      0],
                             [-0.269, -0.667,  -0.76, -0.655, -0.522, -0.336, -0.181, -0.096,  0.029,  0.136,  0.188,  0.286,
                                0.37,  0.346,  0.345,  0.396,  0.342,   0.15, -0.102, -0.307, -0.473, -0.661, -0.528,    0.2,
                               0.393,  0.324,  0.405,  0.162,      0,      0,      0,      0,      0],
                             [-0.255, -0.653, -0.747, -0.643, -0.511, -0.325, -0.169, -0.082,  0.042,  0.149,  0.204,  0.304,
                               0.388,  0.363,  0.36 ,  0.409,  0.354,  0.164, -0.085, -0.289, -0.457, -0.649, -0.523,  0.193,
                               0.394,  0.326,  0.406,  0.162,      0,      0,      0,      0,      0],
                             [-0.265,  -0.65, -0.739, -0.634,   -0.5, -0.314, -0.159, -0.072,  0.052,  0.159,  0.215,  0.316,
                               0.398,  0.374,  0.374,  0.424,   0.37,  0.181, -0.065, -0.265, -0.429, -0.627, -0.519,   0.18,
                               0.394,  0.326,  0.406,  0.162,      0,      0,      0,      0,      0],
                             [-0.276, -0.647, -0.731, -0.626, -0.492, -0.307, -0.152, -0.064,  0.058,  0.166,  0.227,  0.329,
                               0.411,  0.389,   0.39,  0.441,  0.389,  0.207, -0.032, -0.228, -0.394, -0.596, -0.494,  0.194,
                               0.376,  0.326,  0.406,  0.162,      0,      0,      0,      0,      0],
                             [-0.271, -0.646,  -0.73, -0.625, -0.489, -0.303, -0.149, -0.061,  0.062,  0.169,  0.229,  0.332,
                               0.412,  0.388,  0.389,  0.439,  0.387,  0.206, -0.028, -0.209, -0.347, -0.524, -0.435,  0.195,
                               0.381,  0.313,  0.405,  0.162,      0,      0,      0,      0,      0],
                             [-0.267, -0.647, -0.734, -0.628,  -0.49, -0.304, -0.151, -0.062,  0.061,  0.168,  0.229,  0.329,
                               0.408,  0.385,  0.388,  0.438,  0.386,  0.206, -0.024, -0.194, -0.319,  -0.48,  -0.36,  0.318,
                               0.405,  0.335,  0.394,  0.162,      0,      0,      0,      0,      0],
                             [-0.274, -0.656, -0.745,  -0.64,   -0.5, -0.313, -0.158, -0.068,  0.054,  0.161,  0.223,  0.325,
                               0.402,  0.379,  0.384,  0.438,  0.392,  0.221,  0.001, -0.164, -0.278, -0.415, -0.264,  0.445,
                               0.402,  0.304,  0.389,  0.157,      0,      0,      0,      0,      0],
                             [-0.289, -0.666, -0.753, -0.648, -0.508,  -0.32, -0.164, -0.073,  0.049,  0.156,   0.22,  0.321,
                               0.397,  0.374,  0.377,   0.43,  0.387,  0.224,  0.014, -0.139, -0.236, -0.359, -0.211,  0.475,
                                 0.4,  0.308,  0.375,  0.155,      0,      0,      0,      0,      0],
                             [-0.302, -0.678, -0.765, -0.659, -0.517, -0.329, -0.176, -0.085,  0.038,  0.145,  0.208,   0.31,
                               0.386,  0.362,  0.366,  0.421,  0.381,  0.224,  0.022, -0.119, -0.201,   -0.3, -0.129,  0.572,
                               0.419,  0.265,  0.364,  0.154,      0,      0,      0,      0,      0],
                             [-0.314, -0.696, -0.786, -0.681, -0.539, -0.349, -0.196, -0.105,  0.019,  0.127,  0.189,  0.289,
                               0.364,   0.34,  0.346,  0.403,   0.37,  0.222,  0.036, -0.081, -0.133, -0.205, -0.021,  0.674,
                               0.383,  0.237,  0.359,  0.151,      0,      0,      0,      0,      0],
                             [-0.341, -0.719, -0.807, -0.702, -0.558, -0.367, -0.211,  -0.12,  0.003,  0.111,  0.175,  0.277,
                               0.351,  0.325,  0.331,   0.39,   0.36,  0.221,  0.048, -0.046, -0.074, -0.139,  0.038,  0.726,
                               0.429,  0.215,  0.347,  0.151,      0,      0,      0,      0,      0],
                             [ -0.35, -0.737, -0.829, -0.724, -0.577, -0.385, -0.229, -0.136, -0.011,  0.098,  0.163,  0.266,
                               0.338,   0.31,  0.316,  0.378,  0.354,  0.221,  0.062, -0.009, -0.012, -0.063,  0.119,  0.811,
                               0.319,  0.201,  0.343,  0.148,      0,      0,      0,      0,      0],
                             [-0.344,  -0.75, -0.856, -0.757, -0.607, -0.409,  -0.25, -0.156, -0.033,  0.076,  0.143,  0.246,
                               0.316,  0.287,  0.293,  0.361,  0.345,  0.225,  0.082,  0.035,  0.071,  0.046,  0.172,  0.708,
                               0.255,   0.21,  0.325,  0.146,      0,      0,      0,      0,      0]])/86400
        A = np.interp(Gr.z_half,self.Fo.z_in,self.Fo.rad_in[0,:]) # Gr.z_half,self.rad
        for tt in range(1,36):
            A = np.vstack((A, np.interp(Gr.z_half,self.Fo.z_in,self.Fo.rad_in[tt,:])))
        self.Fo.rad = np.multiply(A,1.0) # store matrix in self
        self.Fo.dqtdt =  np.zeros(Gr.nzg, dtype=np.double)

        ind1 = int(math.trunc(10.0/600.0))                   # the index preceding the current time step (first timestep)
        ind2 = int(math.ceil(10.0/600.0))                    # the index following the current time step (first timestep)
        for kk in range(0,Gr.nzg):
            if 10%600.0 == 0:                                 # in case you step right on the data point
                self.Fo.dTdt[kk] = self.Fo.rad[ind1,kk]
            else:                                             # in all other cases
                self.Fo.dTdt[kk]    = (self.Fo.rad[ind2,kk]-self.Fo.rad[ind1,kk])/(self.Fo.rad_time[ind2]-self.Fo.rad_time[ind1])*(10.0)+self.Fo.rad[ind1,kk]

        return


    cpdef initialize_io(self, NetCDFIO_Stats Stats):
        CasesBase.initialize_io(self, Stats)
        return
    cpdef io(self, NetCDFIO_Stats Stats):
        CasesBase.io(self,Stats)
        return

    cpdef update_surface(self, GridMeanVariables GMV, TimeStepping TS):
        self.Sur.lhf = 554.0 * np.power(np.maximum(0, np.cos(np.pi/2*((5.25*3600.0 - TS.t)/5.25/3600.0))),1.3)
        self.Sur.shf = 270.0 * np.power(np.maximum(0, np.cos(np.pi/2*((5.25*3600.0 - TS.t)/5.25/3600.0))),1.5)
        self.Sur.update(GMV)
        return

    cpdef update_forcing(self, GridMeanVariables GMV, Grid Gr, ReferenceState Ref, TimeStepping TS):

        self.Fo.dqtdt =  np.zeros(Gr.nzg, dtype=np.double)
        ind1 = int(math.trunc(TS.t/600.0))                   # the index preceding the current time step
        ind2 = int(math.ceil(TS.t/600.0))                    # the index following the current time step
        if TS.t<600.0: # first 10 min use the radiative forcing of t=10min
            for kk in range(0,Gr.nzg):
                self.Fo.rad_cool[kk] = self.Fo.rad[0,kk]
        elif TS.t>18900.0:
            for kk in range(0,Gr.nzg):
                self.Fo.rad_cool[kk] = (self.Fo.rad[31,kk]-self.Fo.rad[30,kk])/(self.Fo.rad_time[31]-self.Fo.rad_time[30])*(18900.0/60.0-self.Fo.rad_time[30])+self.Fo.rad[30,kk]

        else:
            if TS.t%600.0 == 0:     # in case you step right on the data point
                for kk in range(0,Gr.nzg):
                    self.Fo.rad_cool[kk] = self.Fo.rad[ind1,kk]
            else: # in all other cases - interpolate
                for kk in range(0,Gr.nzg):
                    if Gr.z_half[kk] < 22699.48:
                        self.Fo.rad_cool[kk]    = (self.Fo.rad[ind2,kk]-self.Fo.rad[ind1,kk])/(self.Fo.rad_time[ind2]-self.Fo.rad_time[ind1])*(TS.t/60.0-self.Fo.rad_time[ind1])+self.Fo.rad[ind1,kk]
                    else:
                        self.Fo.rad_cool[kk] = 0.1
        # get the radiative cooling to the moist entropy equation

        self.Fo.update(GMV)

        return



cdef class ARM_SGP(CasesBase):
    def __init__(self, paramlist):
        self.casename = 'ARM_SGP'
        self.Sur = Surface.SurfaceFixedFlux(paramlist)
        self.Fo = Forcing.ForcingRadiative() # it was forcing standard
        self.inversion_option = 'thetal_maxgrad'

        return
    cpdef initialize_reference(self, Grid Gr, ReferenceState Ref, NetCDFIO_Stats Stats):
        Ref.Pg = 970.0*100 #Pressure at ground
        Ref.Tg = 299.0   # surface values for reference state (RS) which outputs p0 rho0 alpha0
        Ref.qtg = 15.2/1000#Total water mixing ratio at surface
        Ref.initialize(Gr, Stats)
        return
    cpdef initialize_profiles(self, Grid Gr, GridMeanVariables GMV, ReferenceState Ref):
        cdef:

            double [:] p1 = np.zeros((Gr.nzg,),dtype=np.double,order='c')

        # ARM_GCSS inputs

        z_in = np.array([0.0, 50.0, 350.0, 650.0, 700.0, 1300.0, 2500.0, 5500.0 ]) #LES z is in meters
        Theta_in = np.array([299.0, 301.5, 302.5, 303.53, 303.7, 307.13, 314.0, 343.2]) # K
        qt_in = np.array([15.2,15.17,14.98,14.8,14.7,13.5,3.0,3.0])/1000 # qt should be in kg/kg

        # interpolate to the model grid-points
        Theta = np.interp(Gr.z_half,z_in,Theta_in)
        qt = np.interp(Gr.z_half,z_in,qt_in)

        GMV.QT.values = np.zeros((Gr.nzg,),dtype=np.double,order='c')
        GMV.QT.values[0] = qt[3]
        GMV.QT.values[1] = qt[2]
        GMV.T.values = np.zeros((Gr.nzg,),dtype=np.double,order='c')
        GMV.T.values[0] = Theta[3]*exner_c(Ref.Pg)
        GMV.T.values[1] = Theta[2]*exner_c(Ref.Pg)
        GMV.T.values[Gr.nzg-Gr.gw+1] = Theta[Gr.nzg-Gr.gw-1]*exner_c(Ref.Pg)

        theta_rho = qt*0.0
        epsi = 287.1/461.5
        cdef double PV_star # here pv_star is a function
        cdef double qv_star

        GMV.U.set_bcs(Gr)
        GMV.T.set_bcs(Gr)

        for k in xrange(Gr.gw,Gr.nzg-Gr.gw):
            GMV.QT.values[k] = qt[k]
            qv = GMV.QT.values[k] - GMV.QL.values[k]
            GMV.T.values[k] = Theta[k]*exner_c(Ref.Pg)
            if GMV.H.name == 's':
                GMV.H.values[k] = t_to_entropy_c(Ref.p0_half[k],GMV.T.values[k],
                                                GMV.QT.values[k], 0.0, 0.0)
            elif GMV.H.name == 'thetal':
                 GMV.H.values[k] = thetali_c(Ref.p0_half[k],GMV.T.values[k],
                                                GMV.QT.values[k], 0.0, 0.0, latent_heat(GMV.T.values[k]))

            GMV.THL.values[k] = thetali_c(Ref.p0_half[k],GMV.T.values[k],
                                                GMV.QT.values[k], 0.0, 0.0, latent_heat(GMV.T.values[k]))
            theta_rho[k] = theta_rho_c(Ref.p0_half[k], GMV.T.values[k], GMV.QT.values[k], qv)



        GMV.QT.set_bcs(Gr)
        GMV.H.set_bcs(Gr)
        GMV.satadjust()

        plt.figure(1)
        plt.plot(GMV.QT.values, Gr.z_half,'b')
        plt.xlabel('qt [kg/kg]')
        plt.ylabel('z [m]')
        plt.figure(2)
        plt.plot(GMV.H.values, Gr.z_half,'r')
        plt.xlabel('Thetali [K]  or Entropy [J/K]')
        plt.ylabel('z [m]')
        plt.show()

        return
    cpdef initialize_surface(self, Grid Gr, ReferenceState Ref):
        self.Sur.zrough = 1.0e-4 # not actually used, but initialized to reasonable value
        self.Sur.Tsurface = 299.0 * exner_c(Ref.Pg)
        self.Sur.qsurface = 15.2e-3 # kg/kg
        self.Sur.lhf = 5.0
        self.Sur.shf = -30.0
        #self.Sur.ustar_fixed = True
        #self.Sur.ustar = 0.0 # m/s Yair ?
        self.Sur.Gr = Gr
        self.Sur.Ref = Ref
        self.Sur.initialize()

        return
    cpdef initialize_forcing(self, Grid Gr, ReferenceState Ref, GridMeanVariables GMV):
        self.Fo.Gr = Gr
        self.Fo.Ref = Ref
        self.Fo.initialize(GMV)
        # only radiative forcing
        self.Fo.subsidence = np.zeros(Gr.nzg, dtype=np.double)
        return


    cpdef initialize_io(self, NetCDFIO_Stats Stats):
        CasesBase.initialize_io(self, Stats)
        return
    cpdef io(self, NetCDFIO_Stats Stats):
        CasesBase.io(self,Stats)
        return

    cpdef update_surface(self, GridMeanVariables GMV, TimeStepping TS):
        t_Sur_in = np.array([0.0, 4.0, 6.5, 7.5, 10.0, 12.5, 14.5]) * 3600 #LES time is in sec
        SH = np.array([-30.0, 90.0, 140.0, 140.0, 100.0, -10, -10]) # W/m^2
        LH = np.array([5.0, 250.0, 450.0, 500.0, 420.0, 180.0, 0.0]) # W/m^2
        self.Sur.shf = np.interp(TS.t,t_Sur_in,SH)
        self.Sur.lhf = np.interp(TS.t,t_Sur_in,LH)
        # if fluxes vanish bflux vanish and wstar and obukov length are NaNs
        if self.Sur.shf < 1.0:
            self.Sur.shf = 1.0
        if self.Sur.lhf < 1.0:
            self.Sur.lhf = 1.0
        self.Sur.bflux = (g * ((self.Sur.shf + (eps_vi-1.0)*(self.Sur.Tsurface * self.Sur.lhf  + self.Sur.qsurface * 8.0e-3)) /(self.Sur.Tsurface* (1.0 + (eps_vi-1) * self.Sur.qsurface))))
        self.Sur.update(GMV)
        return

    cpdef update_forcing(self, GridMeanVariables GMV, Grid Gr, ReferenceState Ref, TimeStepping TS):
        self.Fo.dqtdt =  np.zeros(Gr.nzg, dtype=np.double)
        self.Fo.dTdt =  np.zeros(Gr.nzg, dtype=np.double)
        t_in = np.array([0.0, 3.0, 6.0, 9.0, 12.0, 14.5]) * 3600.0 #LES time is in sec
        AT_in = np.array([0.0, 0.0, 0.0, -0.08, -0.016, -0.016])/3600.0 # Advective forcing for theta [K/h] converted to [K/sec]
        RT_in = np.array([-0.125, 0.0, 0.0, 0.0, 0.0, -0.1])/3600.0  # Radiative forcing for theta [K/h] converted to [K/sec]
        Rqt_in = np.array([0.08, 0.02, 0.04, -0.1, -0.16, -0.3])/1000.0/3600.0 # Radiative forcing for qt converted to [kg/kg/sec]
        dTdt = np.interp(TS.t,t_in,AT_in) + np.interp(TS.t,t_in,RT_in)
        dqtdt =  np.interp(TS.t,t_in,Rqt_in)
        for k in range(0,Gr.nzg): # correct dims
                if Gr.z_half[k] <=1000:
                    self.Fo.dTdt[k] = dTdt
                    self.Fo.dqtdt[k]  = dqtdt * exner_c(Ref.p0_half[k])
                elif Gr.z_half[k] > 1000  and Gr.z_half[k] <= 2000:
                    self.Fo.dTdt[k] = dTdt*(1-(Gr.z_half[k]-1000)/1000)
                    self.Fo.dqtdt[k]  = dqtdt * exner_c(Ref.p0_half[k])*(1-(Gr.z_half[k]-1000)/1000)
        self.Fo.update(GMV)

        return


cdef class SCMS(CasesBase):
    def __init__(self, paramlist):
        self.casename = 'SCMS'
        self.Sur = Surface.SurfaceFixedFlux(paramlist)
        self.Fo = Forcing.ForcingRadiative() # it was forcing standard
        self.inversion_option = 'thetal_maxgrad'

        return
    cpdef initialize_reference(self, Grid Gr, ReferenceState Ref, NetCDFIO_Stats Stats):
        Ref.Pg = 1013.0*100 # Pressure at surface was not stated in Neggers et al. 2003
        Ref.Tg = 297.0    # surface values for reference state (RS) which outputs p0 rho0 alpha0
        Ref.qtg = 17.5/1000 #Total water mixing ratio at surface
        Ref.initialize(Gr, Stats)

        return
    cpdef initialize_profiles(self, Grid Gr, GridMeanVariables GMV, ReferenceState Ref):
        cdef:

            double [:] p1 = np.zeros((Gr.nzg,),dtype=np.double,order='c')
            double [:] qt = np.zeros((Gr.nzg,),dtype=np.double,order='c')
            double [:] T = np.zeros((Gr.nzg,),dtype=np.double,order='c')
            double [:] theta_rho = np.zeros((Gr.nzg,),dtype=np.double,order='c')

        for k in xrange(Gr.gw,Gr.nzg-Gr.gw):
            if Gr.z_half[k] <= 1500:
                T[k] = (Ref.Tg - Gr.z_half[k]/1500*(297-303))*exner_c(Ref.p0_half[k])
            elif Gr.z_half[k] > 1500 and Gr.z_half[k] <= 2200:
                T[k] = (303 - (Gr.z_half[k]-1500)/700*(303 - 311))*exner_c(Ref.p0_half[k])
            elif Gr.z_half[k] > 2200: #and Gr.z_half[k] <= 3000:
                T[k] = (311 - (Gr.z_half[k]-2200)/800*(311 - 312))*exner_c(Ref.p0_half[k])
        T[0] = T[3]
        T[1] = T[2]
        T[Gr.nzg-2]  = T[Gr.nzg-Gr.gw-2]
        T[Gr.nzg-1]  = T[Gr.nzg-Gr.gw-3]
        #T[Gr.nzg]    = T[Gr.nzg-Gr.gw-2]
        for k in xrange(Gr.gw,Gr.nzg-Gr.gw):
            if Gr.z_half[k] <= 800:
                qt[k] = Ref.qtg*1000 - Gr.z_half[k]/800*(17.5-16)
            elif Gr.z_half[k] > 800 and Gr.z_half[k] <= 1500:
                qt[k] = 16 - (Gr.z_half[k]-800)/700*(16 - 13)
            elif Gr.z_half[k] > 1500 and Gr.z_half[k] <= 2100:
                qt[k] = 13 - (Gr.z_half[k]-1500)/600*(13 - 3)
            elif Gr.z_half[k] > 2100:
                qt[k] = 3
        qt[0] = qt[3]
        qt[1] = qt[2]
        qt[Gr.nzg-1]  = qt[Gr.nzg-Gr.gw-3]
        qt[Gr.nzg-2]  = qt[Gr.nzg-Gr.gw-2]
        qt = np.divide(qt,1000.0) # in [kg/kg]

        GMV.QT.values = np.zeros((Gr.nzg,),dtype=np.double,order='c')
        GMV.QT.values[0] = qt[3]
        GMV.QT.values[1] = qt[2]
        GMV.QT.values[Gr.nzg-Gr.gw+1] = qt[Gr.nzg-Gr.gw-1]

        GMV.T.values = np.zeros((Gr.nzg,),dtype=np.double,order='c')
        GMV.T.values[0] = T[3]
        GMV.T.values[1] = T[2]
        GMV.T.values[Gr.nzg-Gr.gw+1] = T[Gr.nzg-Gr.gw-1]

        epsi = 287.1/461.5
        cdef double PV_star # here pv_star is a function
        cdef double qv_star

        GMV.U.set_bcs(Gr)
        GMV.T.set_bcs(Gr)

        for k in xrange(Gr.gw,Gr.nzg-Gr.gw):
            GMV.T.values[k] = T[k]
            GMV.QT.values[k] = qt[k]
            qv = GMV.QT.values[k] - GMV.QL.values[k]
            if GMV.H.name == 's':
                GMV.H.values[k] = t_to_entropy_c(Ref.p0_half[k],GMV.T.values[k],
                                                GMV.QT.values[k], 0.0, 0.0)
            elif GMV.H.name == 'thetal':
                 GMV.H.values[k] = thetali_c(Ref.p0_half[k],GMV.T.values[k],
                                                GMV.QT.values[k], 0.0, 0.0, latent_heat(GMV.T.values[k]))

            GMV.THL.values[k] = thetali_c(Ref.p0_half[k],GMV.T.values[k],
                                                GMV.QT.values[k], 0.0, 0.0, latent_heat(GMV.T.values[k]))
            theta_rho[k] = theta_rho_c(Ref.p0_half[k], GMV.T.values[k], GMV.QT.values[k], qv)

        GMV.QT.set_bcs(Gr)
        GMV.H.set_bcs(Gr)
        GMV.satadjust()


        plt.figure(1)
        plt.plot(GMV.QT.values, Gr.z_half)
        plt.figure(2)
        plt.plot(GMV.H.values, Gr.z_half)
        plt.show()

        return
    cpdef initialize_surface(self, Grid Gr, ReferenceState Ref):
        self.Sur.zrough = 1.0e-4 # not actually used, but initialized to reasonable value
        self.Sur.Tsurface = 299.0 * exner_c(Ref.Pg)
        self.Sur.qsurface = 15.2e-3 # kg/kg
        self.Sur.lhf = 0.0
        self.Sur.shf = 0.0
        self.Sur.ustar_fixed = True
        self.Sur.ustar = 0.1 # m/s Yair ?
        self.Sur.Gr = Gr
        self.Sur.Ref = Ref
        # where is z0 inserted here
        self.Sur.shf = 1.0
        self.Sur.lhf = 1.0
        self.Sur.bflux = (g * ((self.Sur.shf + (eps_vi-1.0)*(self.Sur.Tsurface * self.Sur.lhf  + self.Sur.qsurface * 8.0e-3)) /(self.Sur.Tsurface* (1.0 + (eps_vi-1) * self.Sur.qsurface))))
        self.Sur.initialize()

        return
    cpdef initialize_forcing(self, Grid Gr, ReferenceState Ref, GridMeanVariables GMV):
        self.Fo.Gr = Gr
        self.Fo.Ref = Ref
        self.Fo.initialize(GMV)
        # only radiative forcing
        self.Fo.subsidence = np.zeros(Gr.nzg, dtype=np.double)
        self.Fo.dqtdt = np.zeros((Gr.nzg,),dtype=np.double,order='c')
        self.Fo.dTdt = np.zeros((Gr.nzg,),dtype=np.double,order='c')
        return


    cpdef initialize_io(self, NetCDFIO_Stats Stats):
        CasesBase.initialize_io(self, Stats)
        return
    cpdef io(self, NetCDFIO_Stats Stats):
        CasesBase.io(self,Stats)
        return

    cpdef update_surface(self, GridMeanVariables GMV, TimeStepping TS):
        self.Sur.shf = 100.0*np.sin(TS.t*np.pi/(12.0*3600.0))
        self.Sur.lhf = 300.0*np.sin(TS.t*np.pi/(12.0*3600.0))
        if self.Sur.shf < 1.0:
            self.Sur.shf = 1.0
        if self.Sur.lhf < 1.0:
            self.Sur.lhf = 1.0
        self.Sur.bflux = (g * ((self.Sur.shf + (eps_vi-1.0)*(self.Sur.Tsurface * self.Sur.lhf  + self.Sur.qsurface * 8.0e-3)) /(self.Sur.Tsurface* (1.0 + (eps_vi-1) * self.Sur.qsurface))))
        self.Sur.update(GMV)
        return

    cpdef update_forcing(self, GridMeanVariables GMV, Grid Gr, ReferenceState Ref, TimeStepping TS):

        for k in range(0,Gr.nzg): # ask Roel Neggers for the real zi definition
            if Gr.z_half[k] <=self.zi:
                self.Fo.dTdt[k] = -3.0*(1.0 + Gr.z_half[k]/self.zi)/(24.0*3600.0)

        self.Fo.update(GMV)

        return

cdef class GATE_III(CasesBase):
    def __init__(self, paramlist):
        self.casename = 'GATE_III'
        self.Sur = Surface.SurfaceFixedFlux(paramlist)
        self.Fo = Forcing.ForcingRadiative() # it was forcing standard
        self.inversion_option = 'thetal_maxgrad'

        return
    cpdef initialize_reference(self, Grid Gr, ReferenceState Ref, NetCDFIO_Stats Stats):
        Ref.Pg = 1013.0*100  #Pressure at ground
        Ref.Tg = 299.88   # surface values for reference state (RS) which outputs p0 rho0 alpha0
        Ref.qtg = 16.5/1000#Total water mixing ratio at surface
        Ref.initialize(Gr, Stats)
        return
    cpdef initialize_profiles(self, Grid Gr, GridMeanVariables GMV, ReferenceState Ref):
        cdef:
            double qv
            double [:] qt = np.zeros((Gr.nzg,),dtype=np.double,order='c')
            double [:] T = np.zeros((Gr.nzg,),dtype=np.double,order='c') # Gr.nzg = Gr.nz + 2*Gr.gw
            double [:] U = np.zeros((Gr.nzg,),dtype=np.double,order='c')
            double [:] theta_rho = np.zeros((Gr.nzg,),dtype=np.double,order='c')

        # GATE_III inputs
        z_in  = np.array([ 0.0,   0.5,  1.0,  1.5,  2.0,   2.5,    3.0,   3.5,   4.0,   4.5,   5.0,  5.5,  6.0,  6.5, 7.0, 7.5, 8.0,  8.5,   9.0,   9.5,  10.0,   10.5,   11.0, 11.5, 12.0, 12.5, 13.0, 13.5, 14.0, 14.5, 15.0, 15.5, 16.0, 16.5, 17.0, 17.5, 18.0, 27.0]) * 1000.0 #LES z is in meters
        qt_in = np.array([16.5,  16.5, 13.5, 12.0, 10.0,   8.7,    7.1,   6.1,   5.2,   4.5,   3.6,  3.0,  2.3, 1.75, 1.3, 0.9, 0.5, 0.25, 0.125, 0.065, 0.003, 0.0015, 0.0007,  0.0003,  0.0001,  0.0001,  0.0001,  0.0001,  0.0001,  0.0001,  0.0001,  0.0001,  0.0001,  0.0001,  0.0001,  0.0001,  0.0001, 0.0001])/1000 # qt should be in kg/kg
        U_in  = np.array([  -1, -1.75, -2.5, -3.6, -6.0, -8.75, -11.75, -13.0, -13.1, -12.1, -11.0, -8.5, -5.0, -2.6, 0.0, 0.5, 0.4,  0.3,   0.0,  -1.0,  -2.5,   -3.5,   -4.5, -4.8, -5.0, -3.5, -2.0, -1.0, -1.0, -1.0, -1.5, -2.0, -2.5, -2.6, -2.7, -3.0, -3.0, -3.0])# [m/s]
        T_in = np.array([299.184, 294.836, 294.261, 288.773, 276.698, 265.004, 253.930, 243.662, 227.674, 214.266, 207.757, 201.973, 198.278, 197.414, 198.110, 198.110])
        z_T_in = np.array([0.0, 0.492, 0.700, 1.698, 3.928, 6.039, 7.795, 9.137, 11.055, 12.645, 13.521, 14.486, 15.448, 16.436, 17.293, 22.0])*1000.0 # for km
        # interpolate to the model grid-points


        T = np.interp(Gr.z_half,z_T_in,T_in) # interpolate to ref pressure level
        GMV.T.values[0] = T[3]
        GMV.T.values[1] = T[2]
        GMV.T.values[Gr.nzg-Gr.gw+1] = T[Gr.nzg-Gr.gw-1]

        qt = np.interp(Gr.z_half,z_in,qt_in)
        GMV.QT.values[0] = qt[3]
        GMV.QT.values[1] = qt[2]
        GMV.QT.values[Gr.nzg-Gr.gw+1] = qt[Gr.nzg-Gr.gw-1]

        U = np.interp(Gr.z_half,z_in,U_in)
        GMV.U.values[0] = U[3]
        GMV.U.values[1] = U[2]
        GMV.U.values[Gr.nzg-Gr.gw+1] = U[Gr.nzg-Gr.gw-1]

        GMV.V.values = np.zeros((Gr.nzg,),dtype=np.double,order='c')

        GMV.U.set_bcs(Gr)
        GMV.T.set_bcs(Gr)


        for k in xrange(Gr.gw,Gr.nzg-Gr.gw):
            GMV.QT.values[k] = qt[k]
            GMV.T.values[k] = T[k]
            GMV.U.values[k] = U[k]
            qv = GMV.QT.values[k] - GMV.QL.values[k]
            if GMV.H.name == 's':
                GMV.H.values[k] = t_to_entropy_c(Ref.p0_half[k],GMV.T.values[k],
                                                GMV.QT.values[k], 0.0, 0.0)
            elif GMV.H.name == 'thetal':
                 GMV.H.values[k] = thetali_c(Ref.p0_half[k],GMV.T.values[k],
                                                GMV.QT.values[k], 0.0, 0.0, latent_heat(GMV.T.values[k]))

            GMV.THL.values[k] = thetali_c(Ref.p0_half[k],GMV.T.values[k],
                                                GMV.QT.values[k], 0.0, 0.0, latent_heat(GMV.T.values[k]))
            theta_rho[k] = theta_rho_c(Ref.p0_half[k], GMV.T.values[k], GMV.QT.values[k], qv)

        GMV.QT.set_bcs(Gr)
        GMV.H.set_bcs(Gr)
        GMV.satadjust()


        plt.figure(1)
        plt.plot(GMV.QT.values, Gr.z_half)
        plt.figure(2)
        plt.plot(GMV.H.values, Gr.z_half)
        plt.show()

        return
    cpdef initialize_surface(self, Grid Gr, ReferenceState Ref):
        self.Sur.zrough = 1.0e-4 # not actually used, but initialized to reasonable value
        self.Sur.Tsurface = 299.88 * exner_c(Ref.Pg)
        self.Sur.qsurface = 16.5/1000.0 # kg/kg
        self.Sur.ustar_fixed = False
        self.Sur.Gr = Gr
        self.Sur.Ref = Ref
        # yair - this was just compied from Bomex hoiw do oyu calculate LHF and SHF from bulk formula ?
        self.Sur.bflux = (g * ((8.0e-3 + (eps_vi-1.0)*(299.1 * 5.2e-5  + 22.45e-3 * 8.0e-3)) /(299.1 * (1.0 + (eps_vi-1) * 22.45e-3))))
        #print('self.Sur.bflux =',self.Sur.bflux )
        #self.Sur.bflux = (g * ((self.Sur.shf + (eps_vi-1.0)*(self.Sur.Tsurface * self.Sur.lhf  + self.Sur.qsurface * 8.0e-3)) /(self.Sur.Tsurface* (1.0 + (eps_vi-1) * self.Sur.qsurface))))
        self.Sur.initialize()

        return
    cpdef initialize_forcing(self, Grid Gr, ReferenceState Ref, GridMeanVariables GMV):
        self.Fo.Gr = Gr
        self.Fo.Ref = Ref
        self.Fo.initialize(GMV)
        self.Fo.dqtdt =  np.zeros(Gr.nzg, dtype=np.double)
        self.Fo.dTdt =  np.zeros(Gr.nzg, dtype=np.double)
        # GATE_III  forcing
        self.Fo.subsidence = np.zeros(Gr.nzg, dtype=np.double)
        z_in     = np.array([ 0.0,   0.5,  1.0,  1.5,   2.0,   2.5,    3.0,   3.5,   4.0,   4.5,   5.0,   5.5,   6.0,   6.5,  7.0,  7.5,   8.0,  8.5,   9.0,  9.5,  10.0,  10.5,  11.0,    11.5,   12.0, 12.5,  13.0, 13.5, 14.0, 14.5, 15.0, 15.5, 16.0, 16.5, 17.0, 17.5, 18.0]) * 1000.0 #LES z is in meters
        u_in     = np.array([  -1, -1.75, -2.5, -3.6,  -6.0, -8.75, -11.75, -12.9, -13.1, -12.1, -11.0,  -8.5,  -5.0,  -2.6,  0.0,  0.5,   0.4,  0.3,   0.0, -1.0,  -3.0,  -3.5,  -4.5,    -4.6,   -5.0, -3.5,  -2.0, -1.0, -1.0, -1.0, -1.5, -2.0, -2.5, -2.6, -2.7, -3.0, -3.0])
        RAD_in   = np.array([-2.9,  -1.1, -0.8, -1.1, -1.25, -1.35,   -1.4,  -1.4, -1.44, -1.52,  -1.6, -1.54, -1.49, -1.43, -1.36, -1.3, -1.25, -1.2, -1.15, -1.1, -1.05,  -1.0,  -0.95,   -0.9,  -0.85, -0.8, -0.75, -0.7, -0.6, -0.3,  0.0,  0.0,  0.0,  0.0,  0.0,  0.0,  0.0])/(24.0*3600.0)  # Radiative forcing for T [K/d] converted to [K/sec]
        Qtend_in = np.array([ 0.0,   1.2,  2.0,  2.3,   2.2,   2.1,    1.9,   1.7,   1.5,  1.35,  1.22,  1.08,  0.95,  0.82,  0.7,  0.6,   0.5,  0.4,   0.3,  0.2,   0.1,  0.05, 0.0025, 0.0012, 0.0006,  0.0,   0.0,  0.0,  0.0,  0.0,  0.0,  0.0,  0.0,  0.0,  0.0,  0.0,  0.0])/(24.0*3600.0)/1000.0  # Advective qt forcing  for theta [g/kg/d] converted to [kg/kg/sec]
        Ttend_in = np.array([ 0.0,  -1.0, -2.2, -3.0,  -3.5,  -3.8,   -4.0,  -4.1,  -4.2,  -4.2,  -4.1,  -4.0, -3.85,  -3.7, -3.5, -3.25, -3.0, -2.8,  -2.5, -2.1,  -1.7,  -1.3,   -1.0,   -0.7,   -0.5, -0.4,  -0.3, -0.2, -0.1,-0.05,  0.0,  0.0,  0.0,  0.0,  0.0,  0.0,  0.0])/(24.0*3600.0)  # Radiative T forcing [K/d] converted to [K/sec]

        self.Fo.dqtdt = np.interp(Gr.z_half,z_in,Qtend_in)
        self.Fo.dTdt = np.interp(Gr.z_half,z_in,Ttend_in) + np.interp(Gr.z_half,z_in,RAD_in)
        return


    cpdef initialize_io(self, NetCDFIO_Stats Stats):
        CasesBase.initialize_io(self, Stats)
        return
    cpdef io(self, NetCDFIO_Stats Stats):
        CasesBase.io(self,Stats)
        return

    cpdef update_surface(self, GridMeanVariables GMV, TimeStepping TS):
        # Surface fluxes in GATE_III are wind dependent consider reading these values from GATE_III pycles simulation like in Rico :

        #t_in=nc.Dataset('/Users/yaircohen/Documents/PyCLES_out/Output.Rico.standard/stats/Stats.Rico.nc', 'r').groups['timeseries'].variables['t']
        #lhf_in=nc.Dataset('/Users/yaircohen/Documents/PyCLES_out/Output.Rico.standard/stats/Stats.Rico.nc', 'r').groups['timeseries'].variables['lhf_surface_mean']
        #shf_in=nc.Dataset('/Users/yaircohen/Documents/PyCLES_out/Output.Rico.standard/stats/Stats.Rico.nc', 'r').groups['timeseries'].variables['shf_surface_mean']
        #if TS.t<100.0:
        #    self.Sur.lhf = lhf_in[1]
        #    self.Sur.shf = shf_in[1]
        #elif TS.t<=86400:
        #    if TS.t%100.0 == 0:  # in case you step right on the data point
        #        self.Sur.lhf = lhf_in[TS.t/100.0]
        #        self.Sur.shf = shf_in[TS.t/100.0]
        #    else:
        #        self.Sur.lhf = (lhf_in[TS.t%100.0+1]-lhf_in[TS.t%100.0])/(t_in[TS.t%100.0+1]-t_in[TS.t%100.0])*TS.dt+lhf_in[TS.t%100.0]
        #        self.Sur.shf = (shf_in[TS.t%100.0+1]-shf_in[TS.t%100.0])/(t_in[TS.t%100.0+1]-t_in[TS.t%100.0])*TS.dt+shf_in[TS.t%100.0]
        #else:
        #    self.Sur.lhf = lhf_in[864]
        #    self.Sur.shf = shf_in[864]
        self.Sur.lhf = 5.0 # I just made up values for compiling here
        self.Sur.shf = 3.0
        self.Sur.update(GMV) # here lhf and shf are needed for calcualtion of bflux in surface and thus u_star
        return

    cpdef update_forcing(self, GridMeanVariables GMV, Grid Gr, ReferenceState Ref, TimeStepping TS):
        self.Fo.update(GMV)
        return



