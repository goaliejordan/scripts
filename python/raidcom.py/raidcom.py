#!/usr/bin/python

import sys, getopt, os, re, shutil

class RAID:
  raidcom = '/HORCM/usr/bin/raidcom'
  def __init__(self, array_sn, instance='7'):
    self.sn = array_sn
    self.p2p_ports = []
    self.otherports = []
    self.portname2wwn = {}
    self.instance = instance
    self.lun_capacity = 0
    self.lun_ports = 0
    self.lun_pool = ''

    
  def get_ports(self):
    command = RAID.raidcom + ' get port -s ' + self.sn + ' -I' + self.instance
    output = os.popen(command)
 
    for line in output:
      line = line.strip()  
 
      if re.search('Y    PtoP  Y',line):      
        self.p2p_ports.append(line)
        port_detail = line.split()
        name = port_detail[0]
        wwn = port_detail[10]
        self.portname2wwn[name] =  wwn
      else:
        self.otherports.append(line)      
    if len(self.p2p_ports) > 0: return 1
    return 0
    
  def get_hostgroups(self,port):
    command = RAID.raidcom + ' get host_grp -port  ' + port + '  -s ' + self.sn + ' -I' + self.instance
    output = os.popen(command)
    hostgroups = []
    for line in output:
      line = line.strip()  
      groupfields = line.split()
      GID = groupfields[1]
      initiator = groupfields[2]
      OS = groupfields[4]      
      if re.search('\d+',GID):
        if int(GID) > 0:
          hostgroups.append(GID + ' ' + initiator + ' ' + OS)
    return hostgroups

  def get_hostluns(self,port):
    command = RAID.raidcom + ' get lun -port  ' + port + '  -s ' + self.sn + ' -I' + self.instance
    output = os.popen(command)
    luns = []
    for line in output:
      line = line.strip()
      if re.search('GID',line):
        pass
      else:
        lun = line.split()
        lun_id = lun[5] 
        hex_lun_id = hex(int(lun_id))
        hex_lun_id = hex_lun_id[2:]
        update = lun[3] +'\t' + lun[5] + '\t' + hex_lun_id        
        luns.append(update)
    return luns
 
  def get_lun_detail(self,ldev_decimal):
    command = RAID.raidcom + ' get ldev -ldev_id   ' + ldev_decimal + '  -s ' + self.sn + ' -I' + self.instance
    output = os.popen(command)
    self.lun_detail = []
    self.lun_capacity = 0
    self.lun_ports = 0
    self.lun_pool = ''
    for line in output:
      self.lun_detail.append(line)
      line = line.strip()
      if re.search('VOL_Capacity',line):
        self.lun_capacity = self.get_val(line,':',1)
        self.lun_capacity = round(float(self.lun_capacity) / 2 / 1024 / 1024,2)
      elif re.search('NUM_PORT',line):
        self.lun_ports = self.get_val(line,':',1)
      elif re.search('B_POOLID',line):
        self.lun_pool = self.get_val(line,':',1)
    return 0    
  
  def get_val(self,txt,delimiter,pos):
    fields = txt.split(delimiter)
    if (len(fields) -1) < pos:    
      return ''
    else:
      return fields[pos].strip()



