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

import argparse
import json


def main():
    # Parse information from the command line
    parser = argparse.ArgumentParser(prog='SCAMPy')
    parser.add_argument("namelist")
    parser.add_argument("paramlist")
    args = parser.parse_args()

    file_namelist = open(args.namelist).read()
    namelist = json.loads(file_namelist)
    del file_namelist

    file_paramlist = open(args.paramlist).read()
    paramlist = json.loads(file_paramlist)
    del file_paramlist

    main1d(namelist, paramlist)

    return

def main1d(namelist, paramlist):
    import Simulation1d
    Simulation = Simulation1d.Simulation1d(namelist, paramlist)
    Simulation.initialize(namelist)
    Simulation.run()
    print('The simulation has completed.')

    return

if __name__ == "__main__":
    main()





