#!/usr/bin/python

import sys, getopt, os, re, shutil, time
from raidcom import RAID 


def main(sn,inst,array_name):
  array = RAID(sn,inst)
  status = array.get_ports()
  if status:
    for portname in array.portname2wwn:
      print portname,array.portname2wwn[portname]
      hostgroups = array.get_hostgroups(portname)
      for group in hostgroups:
        GID,initiator,OS = group.split()
        group_translated = portname + '-' + GID
        luns = array.get_hostluns(group_translated)
        for lun in luns:
          host_lun_number, lun_id, lun_id_hex = lun.split()
          array.get_lun_detail(lun_id)
          print host_lun_number, lun_id, lun_id_hex, 'Capacity=', array.lun_capacity, '#Ports=', array.lun_ports, 'POOL=', array.lun_pool
          
          time.sleep(2)
        
         
SubSystems = {}
SubSystems['66195'] = 'SSC_VSP2'

HorcmInst = {}
HorcmInst['66195'] = '7'    
# Boiler plate call to main()
if __name__ == '__main__':
  for sn in SubSystems.keys():
    instance = HorcmInst[sn]
    main(sn,instance,SubSystems[sn])
sys.exit()
    
    