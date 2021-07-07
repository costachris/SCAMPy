#!python
#cython: boundscheck=False
#cython: wraparound=False
#cython: initializedcheck=False
#cython: cdivision=True
from Grid cimport Grid
import netCDF4 as nc
import numpy as np

cdef class TimeStepping:

    def __init__(self, Gr, namelist):
        try:
            self.dt = namelist['time_stepping']['dt']
        except:
            self.dt = 1.0

        self.dti = 1.0/self.dt

        try:
            if namelist['meta']['casename'] == 'LES_driven_SCM':
                lesfolder = namelist['meta']['lesfolder']
                lesfile = namelist['meta']['lesfile']
                les_data = nc.Dataset(lesfolder + 'Stats.' + lesfile +'.nc','r')
                self.t_max = np.max(les_data.groups['profiles'].variables['t'])
            else:
                self.t_max = namelist['time_stepping']['t_max']
        except:
            self.t_max = 7200.0


        # set time
        self.t = 0.0
        self.nstep = 0


        return

    cpdef update(self):
        self.t += self.dt
        self.nstep += 1
        return