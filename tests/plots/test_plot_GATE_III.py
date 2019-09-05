import sys, os
PS = os.sep
code_path = os.path.dirname(os.path.realpath(__file__))
while not code_path.endswith('SCAMPy'):
    code_path = os.path.dirname(code_path)
    if not 'SCAMPy' in code_path: break
code_path = code_path+PS
test_path = code_path+PS+'tests'+PS
plot_path = code_path+PS+'tests'+PS+'plots'+PS
sys.path.insert(0, code_path)
sys.path.insert(0, test_path)
sys.path.insert(0, plot_path)

import os
import subprocess
import json
import warnings

from netCDF4 import Dataset

import pytest
import pprint as pp
import numpy as np

import main as scampy
import common as cmn
import plot_scripts as pls

@pytest.fixture(scope="module")
def sim_data(request):

    # generate namelists and paramlists
    setup = cmn.simulation_setup('GATE_III')

    # run scampy
    scampy.main1d(setup["namelist"], setup["paramlist"])

    # simulation results
    sim_data = Dataset(setup["outfile"], 'r')

    # remove netcdf file after tests
    request.addfinalizer(cmn.removing_files)

    return sim_data

@pytest.mark.skip(reason="GATE simulation hangs up")
def test_plot_GATE_III(sim_data):
    """
    plot GATE_III profiles
    """
    data_to_plot = cmn.read_data_avg(sim_data, n_steps=100)

    pls.plot_mean(data_to_plot,   "GATE_III_quicklook.pdf")
    pls.plot_drafts(data_to_plot, "GATE_III_quicklook_drafts.pdf")

@pytest.mark.skip(reason="GATE simulation hangs up")
def test_plot_timeseries_GATE_III(sim_data):
    """
    plot timeseries
    """
    data_to_plot = cmn.read_data_srs(sim_data)

    pls.plot_timeseries(data_to_plot, "GATE_III")

@pytest.mark.skip(reason="GATE simulation hangs up")
def test_plot_timeseries_1D_GATE_III(sim_data):
    """
    plot GATE_III 1D timeseries
    """
    data_to_plot = cmn.read_data_timeseries(sim_data)

    pls.plot_timeseries_1D(data_to_plot, "GATE_III_timeseries_1D.pdf")

@pytest.mark.skip(reason="GATE simulation hangs up")
def test_plot_var_covar_GATE_III(sim_data):
    """
    plot GATE III var covar
    """
    data_to_plot = cmn.read_data_avg(sim_data, n_steps=100, var_covar=True)

    pls.plot_var_covar_mean(data_to_plot,       "GATE_III_var_covar_mean.pdf")
    pls.plot_var_covar_components(data_to_plot, "GATE_III_var_covar_components.pdf")
